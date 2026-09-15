🌍 TourMate — Smart Tourism Guide App

<p align="center">
  <b>Explore. Discover. Plan. Travel Smarter.</b>
</p>

<p align="center">
  A cross-platform smart tourism application built with Flutter and Firebase to help travelers discover attractions, explore locations, save destinations, plan trips, and receive personalized travel assistance.
</p>

📌 Overview

TourMate is a smart tourism guide application designed to bring tourism discovery, location exploration, trip planning, reviews, favorites, and personalized recommendations into a single platform.

The project combines Flutter, Firebase, Google Maps, REST APIs, and AI-powered features to create a modern and intelligent travel experience.

The main objective is to reduce the effort required to discover destinations and plan a trip by providing useful travel tools within one application.

✨ Features

🗺️ Explore Tourist Attractions

Browse tourist destinations and attractions

View attraction information and details

Discover places by category

View ratings and reviews

📍 Location & Maps

Interactive map-based exploration

Location-aware attraction discovery

Google Maps integration

Route and navigation support

🔐 Authentication

TourMate supports:

Email & Password

Google Sign-In

Phone Number Authentication

Firebase Authentication

❤️ Favorites

Save interesting destinations

Access saved attractions

Quickly revisit previously saved places

⭐ Reviews & Ratings

View attraction ratings

Read user reviews

Share travel experiences

🧳 Trip Planning

Create and manage trips

Organize selected destinations

View planned destinations in one place

🤖 AI Travel Assistant

The planned AI Travel Assistant can help create personalized travel plans using:

Location context

Available time

User preferences

Attraction ratings

Distance

Opening hours

🎯 Personalized Recommendations

TourMate uses a weighted recommendation model:

Final Score =
0.40 × Preference
+ 0.25 × Rating
+ 0.20 × Distance
+ 0.15 × Popularity

🌦️ Weather Integration

Weather information can be integrated into travel planning.

🔔 Notifications

Firebase Cloud Messaging can be used for travel-related notifications and updates.

👨‍💼 Admin Dashboard

The planned administration module can provide:

Attraction management

User management

Review management

Tourism content management

Application analytics

🏗️ Technology Stack

Technology

Purpose

Flutter

Cross-platform application

Dart

Programming language

Firebase Authentication

User authentication

Cloud Firestore

Cloud database

Firebase Storage

Image/file storage

Firebase Cloud Messaging

Notifications

Google Maps API

Maps and location features

REST APIs

External services

AI / LLM APIs

Smart travel assistance

GoRouter

Application navigation

Google Fonts

UI typography

📱 Application Architecture

tourmate/
│
├── android/
├── ios/
├── web/
│
├── lib/
│   ├── main.dart
│   │
│   ├── core/
│   │   ├── constants/
│   │   ├── router/
│   │   └── theme/
│   │
│   ├── data/
│   │   └── dummy_data.dart
│   │
│   ├── models/
│   │   └── attraction.dart
│   │
│   ├── services/
│   │   ├── auth_service.dart
│   │   └── firestore_service.dart
│   │
│   ├── widgets/
│   │   ├── attraction_card.dart
│   │   ├── category_chip.dart
│   │   └── section_header.dart
│   │
│   └── screens/
│       ├── splash/
│       ├── onboarding/
│       ├── auth/
│       └── main/
│           ├── home_screen.dart
│           ├── explore_screen.dart
│           ├── trips_screen.dart
│           ├── saved_screen.dart
│           └── profile_screen.dart
│
├── firebase.json
├── firestore.rules
├── pubspec.yaml
└── README.md

🔥 Firebase Architecture

TourMate uses Firebase for backend services.

Authentication

Email / Password
Google
Phone

Firestore Collections

The planned data model includes:

users
├── uid
├── name
├── email
├── photoUrl
├── phoneNumber
├── provider
└── role

attractions
├── name
├── description
├── category
├── location
├── rating
├── images
└── popularity

reviews
├── userId
├── attractionId
├── rating
├── review
└── createdAt

favorites
├── userId
└── attractionId

trips
├── userId
├── name
├── destinations
├── startDate
└── endDate

🎨 User Flow

Splash Screen
      ↓
Onboarding
      ↓
Login / Register
      ↓
Preference Setup
      ↓
Home
 ┌────┼────┬────┬────┐
 ↓    ↓    ↓    ↓    ↓
Explore Map Saved Trips Profile
      ↓
Attraction Details
      ↓
Reviews / Favorites
      ↓
Trip Planning
      ↓
AI Travel Assistant

🚀 Getting Started

Prerequisites

Install:

Flutter SDK

Dart SDK

Android Studio

Android SDK

VS Code or Android Studio

Git

Firebase project

Check Flutter:

flutter doctor

Installation

1. Clone the repository

git clone https://github.com/darshan-codes-ai/Smart-Tourism-Guide-App.git

2. Enter the project

cd Smart-Tourism-Guide-App

3. Install dependencies

flutter pub get

4. Configure Firebase

Connect the application to your Firebase project.

Firebase configuration is required for authentication and Firestore functionality.

⚠️ Never commit private service-account credentials, API secrets, or other sensitive credentials to a public repository.

5. Run the application

Check devices:

flutter devices

Run on Android:

flutter run

Run on Chrome:

flutter run -d chrome

🧪 Testing

Run static analysis:

flutter analyze

Run tests:

flutter test

Build Android APK:

flutter build apk

🔐 Security

TourMate uses Firebase Security Rules to protect user data.

The application should ensure that:

Users can access their own profile data

Users cannot modify another user's profile

User roles cannot be arbitrarily changed

API keys are appropriately restricted

Sensitive credentials are not stored in the public repository

For production deployment, consider:

Firebase App Check

Strong Firestore Security Rules

API key restrictions

Secure API endpoints

Role-based admin access

Input validation

Rate limiting

🧠 Smart Recommendation System

                 User Preferences
                         │
                         ↓
                  Attraction Data
                         │
        ┌────────────────┼────────────────┐
        ↓                ↓                ↓
    Preference         Rating          Distance
        │                │                │
        └────────────────┼────────────────┘
                         ↓
                Recommendation Score
                         │
                         ↓
                 Ranked Attractions

Formula:

Score =
0.40(P) +
0.25(R) +
0.20(D) +
0.15(Popularity)

This creates a foundation for personalized tourism recommendations.

🗺️ Google Maps Integration

Google Maps can support:

Tourist attraction markers

Current location

Nearby attraction discovery

Route visualization

Navigation

Location-based recommendations

🤖 AI Travel Assistant

The AI Travel Assistant is designed to act as a personalized travel planning companion.

Example Input

I have one day in Hyderabad.
I like historical places and food.
I want to minimize travel time.

The system can consider:

User preferences
       +
Available time
       +
Attraction ratings
       +
Distance
       +
Opening hours
       ↓
Personalized itinerary

Example:

09:00 AM → Historical Attraction
11:30 AM → Nearby Landmark
01:00 PM → Lunch
03:00 PM → Museum
05:30 PM → Scenic Location
07:00 PM → Food Destination

👨‍💼 Admin Module

Admin Dashboard
      │
      ├── Manage Attractions
      ├── Manage Users
      ├── Manage Reviews
      ├── View Analytics
      └── Manage Tourism Content

🛣️ Development Roadmap

Phase 1 — Project Foundation

Flutter project setup

Material 3 theme

Application routing

Basic UI architecture

Reusable widgets

Dummy attraction data

Phase 2 — Authentication

Firebase project setup

Email authentication integration

Google authentication integration

Phone authentication integration

Complete authentication testing

Phase 3 — Database

Firestore integration

User profiles

Firestore security rules

Attraction database

Reviews database

Favorites database

Trips database

Phase 4 — Maps & Location

Google Maps integration

Current location

Nearby attractions

Route visualization

Navigation support

Phase 5 — Smart Features

Recommendation engine

AI Travel Assistant

Automatic itinerary generation

Weather integration

Notifications

Phase 6 — Admin

Admin authentication

Attraction management

User management

Review management

Analytics dashboard

Phase 7 — Production

UI/UX refinement

Performance optimization

Security hardening

Testing

Documentation

Release build

📊 Future Enhancements

🌐 Multi-language support

📴 Offline-friendly attraction data

🎙️ Voice-based travel assistant

🧭 Advanced route optimization

👥 Group trip planning

📅 Event-based recommendations

🏨 Hotel and restaurant discovery

🚨 Emergency assistance

📈 Advanced tourism analytics

🧠 Advanced AI personalization

🎯 Project Objectives

Provide a centralized tourism discovery platform.

Help users find attractions based on their interests.

Provide location-aware tourism information.

Simplify travel and itinerary planning.

Provide personalized recommendations.

Integrate AI into the tourism experience.

Provide secure user authentication.

Provide administration tools for tourism content.

Build a scalable cross-platform tourism application.

🌟 Why TourMate?

Traditional tourism workflows often require travelers to switch between multiple applications:

Discover Places
      ↓
Check Reviews
      ↓
Find Locations
      ↓
Plan Routes
      ↓
Create Itinerary
      ↓
Save Destinations

TourMate aims to combine these activities:

                 ┌─────────────────┐
                 │     TOURMATE     │
                 └────────┬────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ↓                 ↓                 ↓
    Discover            Explore             Plan
        │                 │                 │
        ↓                 ↓                 ↓
 Recommendations      Maps/Routes       Itineraries
        │                 │                 │
        └─────────────────┼─────────────────┘
                          ↓
                 Smart Travel Experience

📸 Screenshots

Recommended structure:

docs/
└── screenshots/
    ├── home.png
    ├── explore.png
    ├── map.png
    ├── attraction-details.png
    └── profile.png

Example:

![Home Screen](docs/screenshots/home.png)

🤝 Contribution

Contributions and suggestions are welcome.

git clone <your-fork>
cd Smart-Tourism-Guide-App
git checkout -b feature/new-feature

Make your changes, test them, and create a pull request.

📄 License

This project is currently developed for educational and academic purposes.

A suitable open-source license can be added before production release.

👨‍💻 Author

Darshan Kumar

Project

TourMate — Smart Tourism Guide App

Built With

Flutter + Firebase + Google Maps + REST APIs + AI

<p align="center">
  🌍 <b>TourMate</b> — Explore the world smarter.
</p>
