# Sericle

Added OAuth (GitHub), persistent storage using SQLite, likes, and comments. No ads.

## Environment

Set these environment variables when using OAuth:

- GITHUB_CLIENT_ID
- GITHUB_CLIENT_SECRET
- GITHUB_CALLBACK_URL (optional, defaults to http://localhost:3000/auth/github/callback)
- SESSION_SECRET (optional)

## Run locally

1. Install dependencies

   npm install

2. Create a GitHub OAuth app and set the callback URL to http://localhost:3000/auth/github/callback

3. Export env vars and run

   export GITHUB_CLIENT_ID=yourid
   export GITHUB_CLIENT_SECRET=yoursecret
   npm start

Open http://localhost:3000
