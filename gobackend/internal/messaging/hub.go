package messaging

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

const (
	// writeWait is the max time to wait for a write to the client.
	writeWait = 10 * time.Second

	// pongWait is the max time waiting for a pong from the client.
	pongWait = 60 * time.Second

	// pingPeriod must be less than pongWait.
	pingPeriod = (pongWait * 9) / 10

	// maxMessageSize limits the size of an inbound WebSocket frame.
	maxMessageSize = 4096
)

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

// Client represents a single WebSocket connection.
// The Send channel is drained by writePump — only writePump writes
// to the Conn, so we avoid concurrent write panics.
type Client struct {
	UserID uuid.UUID
	Conn   *websocket.Conn
	Send   chan []byte
	hub    *Hub
}

// readPump reads messages from the WebSocket and forwards them to the hub.
// Runs in its own goroutine. On disconnect/error, unregisters the client.
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.Conn.Close()
	}()

	c.Conn.SetReadLimit(maxMessageSize)
	c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		c.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
				log.Printf("[WS] unexpected close from user=%s: %v", c.UserID, err)
			}
			break
		}

		// Parse incoming message as a client event.
		// Currently the only client-to-server event is "send_message".
		var evt clientEvent
		if err := json.Unmarshal(message, &evt); err != nil {
			log.Printf("[WS] invalid frame from user=%s: %v", c.UserID, err)
			continue
		}

		// Dispatch to hub for processing.
		c.hub.incoming <- incomingEvent{client: c, event: evt}
	}
}

// writePump writes messages from the Send channel to the WebSocket.
// Runs in its own goroutine — only this function touches Conn.WriteMessage.
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// Hub closed the channel — send a close frame.
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// ---------------------------------------------------------------------------
// Hub
// ---------------------------------------------------------------------------

// clientEvent is sent from a WebSocket client to the server.
type clientEvent struct {
	Type           string `json:"type"` // "send_message"
	ConversationID string `json:"conversation_id"`
	Content        string `json:"content"`
}

// incomingEvent pairs a client event with the originating client.
type incomingEvent struct {
	client *Client
	event  clientEvent
}

// Hub tracks active WebSocket clients and routes messages between them.
// The Run() goroutine owns the clients map; external callers (e.g.
// BroadcastToUsers) use mu for safe reads.
type Hub struct {
	register   chan *Client
	unregister chan *Client
	incoming   chan incomingEvent
	broadcast  chan broadcastMsg
	done       chan struct{} // close to shut down
	clients    map[uuid.UUID]*Client
	mu         sync.RWMutex // guards reads from outside Run()
	service    *Service
	audit      *AuditLogger
}

// broadcastMsg carries a serialised event plus the list of target user IDs.
type broadcastMsg struct {
	userIDs []uuid.UUID
	data    []byte
}

// NewHub creates a new Hub. Call Run() in a goroutine before use.
func NewHub(service *Service, audit *AuditLogger) *Hub {
	return &Hub{
		register:   make(chan *Client, 64),
		unregister: make(chan *Client, 64),
		incoming:   make(chan incomingEvent, 256),
		broadcast:  make(chan broadcastMsg, 256),
		done:       make(chan struct{}),
		clients:    make(map[uuid.UUID]*Client),
		service:    service,
		audit:      audit,
	}
}

// Run starts the hub event loop. Must be called as: go hub.Run()
// Close hub.done to shut down.
func (h *Hub) Run() {
	for {
		select {
		case <-h.done:
			// Graceful shutdown: close all client connections
			h.mu.Lock()
			for uid, client := range h.clients {
				close(client.Send)
				delete(h.clients, uid)
			}
			h.mu.Unlock()
			log.Println("[WS] hub shut down gracefully")
			return

		case client := <-h.register:
			h.mu.Lock()
			// Replace any existing connection for the same user.
			if old, exists := h.clients[client.UserID]; exists {
				close(old.Send)
				delete(h.clients, old.UserID)
			}
			h.clients[client.UserID] = client
			h.mu.Unlock()
			h.audit.LogWebSocketConnect(client.UserID)

		case client := <-h.unregister:
			h.mu.Lock()
			if existing, ok := h.clients[client.UserID]; ok && existing == client {
				close(client.Send)
				delete(h.clients, client.UserID)
			}
			h.mu.Unlock()
			h.audit.LogWebSocketDisconnect(client.UserID)

		case evt := <-h.incoming:
			// Handle in a goroutine so DB/crypto work doesn't block the loop.
			go h.handleIncoming(evt)

		case msg := <-h.broadcast:
			h.mu.RLock()
			for _, uid := range msg.userIDs {
				if client, ok := h.clients[uid]; ok {
					select {
					case client.Send <- msg.data:
					default:
						// Send buffer full, drop message.
						log.Printf("[WS] dropping message for user=%s (send buffer full)", uid)
					}
				}
			}
			h.mu.RUnlock()
		}
	}
}

// handleIncoming processes a client event (runs in its own goroutine).
func (h *Hub) handleIncoming(evt incomingEvent) {
	switch evt.event.Type {
	case "send_message":
		convID, err := uuid.Parse(evt.event.ConversationID)
		if err != nil {
			h.sendError(evt.client, "invalid conversation_id")
			return
		}
		_, err = h.service.SendMessage(evt.client.UserID, convID, evt.event.Content)
		if err != nil {
			// Only expose known errors to the client.
			switch err {
			case ErrNotMember, ErrWrongDepartment, ErrMessageTooLong,
				ErrEmptyMessage, ErrRateLimited:
				h.sendError(evt.client, err.Error())
			default:
				log.Printf("[WS] send_message error for user=%s: %v", evt.client.UserID, err)
				h.sendError(evt.client, "failed to send message")
			}
		}
		// SendMessage already broadcasts via BroadcastToUsers.

	default:
		h.sendError(evt.client, "unknown event type: "+evt.event.Type)
	}
}

// sendError sends an error event back to a single client.
func (h *Hub) sendError(c *Client, msg string) {
	evt := models.WebSocketEvent{
		Type:    "error",
		Payload: map[string]string{"message": msg},
	}
	data, _ := json.Marshal(evt)
	select {
	case c.Send <- data:
	default:
	}
}

// BroadcastToUsers sends an event to the given users if they're online.
// Goroutine-safe.
func (h *Hub) BroadcastToUsers(userIDs []uuid.UUID, event models.WebSocketEvent) {
	data, err := json.Marshal(event)
	if err != nil {
		log.Printf("[WS] failed to marshal event: %v", err)
		return
	}
	h.broadcast <- broadcastMsg{
		userIDs: userIDs,
		data:    data,
	}
}

// IsOnline checks if a user has an active WebSocket connection.
func (h *Hub) IsOnline(userID uuid.UUID) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	_, ok := h.clients[userID]
	return ok
}

// RegisterClient adds a new client to the hub via the register channel.
func (h *Hub) RegisterClient(client *Client) {
	h.register <- client
}

// Shutdown signals the hub to close all connections and exit Run().
func (h *Hub) Shutdown() {
	close(h.done)
}

// NewClient creates a Client bound to this hub.
func (h *Hub) NewClient(userID uuid.UUID, conn *websocket.Conn) *Client {
	return &Client{
		UserID: userID,
		Conn:   conn,
		Send:   make(chan []byte, 256),
		hub:    h,
	}
}

// StartClient kicks off the read/write pumps. Call after RegisterClient.
func StartClient(c *Client) {
	go c.writePump()
	go c.readPump()
}
