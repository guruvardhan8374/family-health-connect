# Family Health Connect - Frontend Documentation

## 🚀 Overview
**Family Health Connect** is a premium family communication and health monitoring ecosystem. The frontend is built as a highly responsive, real-time single-page application (SPA) with a focus on modern aesthetics (Glassmorphism) and high-performance communication.

---

## 🛠 Tech Stack
- **Framework**: [React.js](https://reactjs.org/) (Vite)
- **Styling**: [Tailwind CSS](https://tailwindcss.com/)
- **Icons**: [Lucide React](https://lucide.dev/)
- **Real-time**: [Socket.IO Client](https://socket.io/)
- **Communication**: [WebRTC](https://webrtc.org/) (Simple-Peer logic)
- **AI Integration**: [Google Gemini Pro](https://deepmind.google/technologies/gemini/) (via Backend API)
- **API Client**: [Axios](https://axios-http.com/)

---

## 📂 Project Structure
```text
frontend/
├── public/                # Static assets & PWA Manifest
├── src/
│   ├── components/        # Reusable UI Components
│   │   ├── chat/          # MessageBubble, StoryBar, CallOverlay
│   │   └── shared/        # Layouts, Buttons, Inputs
│   ├── pages/             # Main Application Views
│   │   ├── Chat.jsx       # The Core Messenger Hub
│   │   ├── Login.jsx      # Premium Auth Experience
│   │   └── Register.jsx   # Onboarding Flow
│   ├── utils/             # Utilities & API Config
│   │   └── api.js         # Centralized Axios Instance
│   ├── App.jsx            # Routing & Global Context
│   └── index.css          # Design Tokens & Global Styles
└── index.html             # Entry point & PWA Meta Tags
```

---

## 🎨 Design System
### **Color Palette (Navy & Brand Blue)**
- **Navy 950**: `#020617` (Deepest background)
- **Navy 900**: `#0F172A` (Secondary containers)
- **Brand Blue**: `#3B82F6` (Primary interactions)
- **Glassmorphism**: `backdrop-blur-xl` with `bg-white/10` and `border-white/10`.

---

## 📡 Real-time Ecosystem

### **1. Messaging (Socket.IO)**
The app connects to a FastAPI Socket.IO server at `port 8001`.
- **Inbound Events**: `new_message`, `user_typing`, `user_status_change`.
- **Outbound Events**: `chat_message`, `typing_status`, `user_online`.

### **2. Voice & Video Calling (WebRTC)**
Implements a custom signaling flow via Socket.IO.
- **Signaling Server**: FastAPI acts as the STUN/TURN coordinator.
- **Components**: `CallOverlay.jsx` handles the local/remote video streams.

### **3. Family Stories**
Ephemeral status updates (24-hour expiration).
- **Fetcher**: `fetchStories()` in `Chat.jsx`.
- **Viewer**: `StoryBar.jsx` for horizontal feed and full-screen modal viewer.

---

## 🧠 AI Health Integration
Integrated with **Gemini Pro** via the Django backend.
- **Triggers**: 
  - `Brain Icon`: Analyzes latest health data vitals.
  - `Zap Icon`: Summarizes current chat conversation.
- **Response**: Injected as a "Family AI" message bubble with distinct styling.

---

## 📱 Hybrid Web & Mobile App (PWA)
The app is engineered as a **Hybrid PWA**, ensuring a single codebase serves both web and mobile users perfectly.

### **1. Mobile App Features**
- **Home Screen Installation**: Via `manifest.json`, users can install the app on iOS and Android.
- **Standalone Mode**: Hides the browser UI (address bar/tabs) for a 100% native look.
- **Splash Screens**: Custom theme colors and icons for the loading experience.
- **Mobile Navigation**: 
  - **Sidebar-to-Chat Toggle**: On mobile, the sidebar is hidden when a chat is active.
  - **Native Gestures**: Large touch targets for calling and media sharing.

### **2. Web App Features**
- **Multi-Pane Layout**: Side-by-side sidebar and chat on desktops.
- **Cross-Platform**: Accessible via any modern browser without installation.
- **Keyboard Shortcuts**: Full support for `Enter` to send and `Esc` to close modals.

---

## ⚙️ Development Commands
### **Start Frontend**
```bash
npm run dev
```

### **Build for Production**
```bash
npm run build
```

---

## 🛠 API Configuration
The frontend communicates with two backend endpoints:
1. **Django API** (`port 8000`): Authentication, Database, AI processing.
2. **FastAPI Socket Hub** (`port 8001`): Real-time events, Signaling.

Base configuration is managed in `src/utils/api.js`.
