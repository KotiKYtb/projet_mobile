# projet_mobile

This project is a Flutter mobile app with a Node.js REST API (Express + Sequelize) and a SQLite database server-side, plus planned local `sqflite` cache for offline-first behavior.

## Backend (API)
- Express server in `API/`
- Auth (JWT), users/roles, events endpoints
- Sequelize with SQLite (`API/data.sqlite`) in dev

## Mobile (Flutter)
- Flutter app in root `lib/`
- Android/iOS/macOS/Linux/Windows targets present

## Getting Started
- Install Flutter and Node.js
- API: `cd API && npm install && npm start`
- App: `flutter run`
