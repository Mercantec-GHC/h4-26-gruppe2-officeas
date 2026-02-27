-- Revert rating to 1-5; drop shift_id and message
ALTER TABLE feedback DROP CONSTRAINT IF EXISTS feedback_rating_check;
ALTER TABLE feedback ADD CONSTRAINT feedback_rating_check CHECK (rating >= 1 AND rating <= 5);
ALTER TABLE feedback DROP COLUMN IF EXISTS shift_id;
ALTER TABLE feedback DROP COLUMN IF EXISTS message;
