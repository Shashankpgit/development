FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install

# Copy source code
COPY . .

# Build the application (optional, if you want only the artifacts in the layer)
RUN npm run build

# Expose the port commonly used by Vite
EXPOSE 5173

# Run in development mode (or change to 'preview' to serve the built artifacts)
# Use --host to ensure it's accessible outside the container
CMD ["npm", "run", "dev", "--", "--host"]
