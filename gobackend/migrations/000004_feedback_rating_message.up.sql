-- Add optional message column to feedback (if not already present from GORM AutoMigrate)
ALTER TABLE feedback ADD COLUMN
IF NOT EXISTS message TEXT;

-- Allow rating 1-10: drop existing check if present, then add new constraint
ALTER TABLE feedback DROP CONSTRAINT IF EXISTS feedback_rating_check;
ALTER TABLE feedback ADD CONSTRAINT feedback_rating_check CHECK (rating >= 1 AND rating <= 10);
