-- Create products table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some sample data
INSERT INTO products (name) VALUES 
    ('Laptop'),
    ('Mouse'),
    ('Keyboard'),
    ('Monitor')
ON CONFLICT DO NOTHING;
