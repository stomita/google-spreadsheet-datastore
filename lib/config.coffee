module.exports =
  clients:
    google:
      client_id: process.env.GOOGLE_CLIENT_ID
      client_secret: process.env.GOOGLE_CLIENT_SECRET
      redirect_uri: process.env.GOOGLE_REDIRECT_URI
      authz_url: "https://accounts.google.com/o/oauth2/auth"
      token_url: "https://accounts.google.com/o/oauth2/token"
      verify_url: "https://www.googleapis.com/oauth2/v1/tokeninfo"

  

