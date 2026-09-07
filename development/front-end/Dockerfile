# ============================================================================
# STAGE 1 -- build the static bundle
# Node and node_modules (hundreds of MB) are needed to COMPILE the app, not to
# serve it. Doing this in a throwaway stage keeps all of it out of the final
# image: no Node, no npm, no source code shipped to production.
# ============================================================================
FROM node:22-alpine AS build

WORKDIR /app

# package*.json first, then npm ci, then the source -- same layer-caching
# trick as the backend. Editing a component does not re-run npm ci.
COPY package.json package-lock.json ./

# npm ci, NOT npm install:
#   ci installs EXACTLY what package-lock.json says and fails if the lock file
#   disagrees with package.json. install may quietly bump versions, which is
#   how a build that passed yesterday breaks today.
RUN npm ci

COPY . .
RUN npm run build          # output goes to /app/dist

# ============================================================================
# STAGE 2 -- serve it
# nginx-unprivileged instead of the standard nginx image: it is preconfigured
# to run as a non-root user on port 8080, which EKS Pod Security Standards
# ("restricted" profile) require.
# ============================================================================
FROM nginxinc/nginx-unprivileged:1.27-alpine

# Where the API lives. Overridden by Helm with the in-cluster Service DNS name,
# e.g. http://shop-api:8000. envsubst substitutes it into the config at start.
ENV BACKEND_URL=http://shop-api:8000

COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# --from=build reaches into stage 1 and takes ONLY the compiled output.
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080
