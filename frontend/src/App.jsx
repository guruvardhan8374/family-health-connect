import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import MainLayout from './layouts/MainLayout';
import Dashboard from './pages/Dashboard';
import HealthHub from './pages/HealthHub';
import FamilyDirectory from './pages/FamilyDirectory';
import Chat from './pages/Chat';
import Emergency from './pages/Emergency';
import Login from './pages/Login';
import Register from './pages/Register';
import OTPVerification from './pages/OTPVerification';
import Settings from './pages/Settings';
import ForgotPassword from './pages/ForgotPassword';
import AISummary from './pages/AISummary';
import HealthComparison from './pages/HealthComparison';
import { AuthProvider } from './contexts/AuthContext';

const ProtectedRoute = ({ children }) => {
  const token = localStorage.getItem('access_token');
  if (!token) {
    return <Navigate to="/login" replace />;
  }
  return children;
};

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/verify-otp" element={<OTPVerification />} />
        <Route path="/forgot-password" element={<ForgotPassword />} />
        
        <Route path="/" element={<ProtectedRoute><MainLayout /></ProtectedRoute>}>
          <Route index element={<Dashboard />} />
          <Route path="health" element={<HealthHub />} />
          <Route path="family" element={<FamilyDirectory />} />
          <Route path="chat" element={<Chat />} />
          <Route path="emergency" element={<Emergency />} />
          <Route path="settings" element={<Settings />} />
          <Route path="ai-intelligence" element={<AISummary />} />
          <Route path="health-comparison" element={<HealthComparison />} />
        </Route>
      </Routes>
    </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
