#!/bin/bash

# Create .env file from Vercel environment variables
echo "SUPABASE_URL=$SUPABASE_URL" > .env
echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env

# Install Flutter if not present
if ! command -v flutter &> /dev/null; then
    echo "Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1
    export PATH="$PATH:`pwd`/flutter/bin"
fi

# Build the web app
flutter config --enable-web
flutter pub get
flutter build web --release
