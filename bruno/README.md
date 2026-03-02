# YourOffice API – Bruno Collection

This folder contains a [Bruno](https://www.usebruno.com/) collection for the YourOffice API.

## Setup

1. Open Bruno and **Open Collection** → select this `bruno` folder.
2. Select the **Production** environment (or create one). Set:
   - `base_url`: `https://officeas-api.mercantec.tech` (or your API base URL)
   - `token`: leave empty; it will be set automatically after **Auth → Login** if you use the post-response script
   - `id`, `ticketId`, `absenceRequestId`: set when testing specific resources
3. Run **Auth → Login** with valid credentials; the response script stores the JWT in `token` for protected requests.

## Structure

- **Health** – `GET /health`
- **Auth** – login, register
- **Departments** – CRUD (GET list is public)
- **Users** – list, get, pending, create, update, approve, delete
- **Tickets** – CRUD
- **Shifts** – CRUD, list by user, generate
- **Absence-requests** – CRUD, approve, sick-today
- **Feedback** – CRUD
- **Notifications** – list, unread-count, mark read, delete
- **Ticket-comments** – list, create, get, update, delete (use `ticketId` in env for list/create)
- **Absence-request-comments** – list, create, get, update, delete (use `absenceRequestId` for list/create)

Replace placeholder UUIDs in bodies and set `id` (and `ticketId` / `absenceRequestId` where needed) in the environment before running requests.
