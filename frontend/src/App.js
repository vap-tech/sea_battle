import * as React from 'react';
import CssBaseline from '@mui/material/CssBaseline';
import AppTheme from './shared-theme/AppTheme';
import AppAppBar from './pages/components/AppAppBar';
import Footer from './pages/components/Footer';

import { BrowserRouter, Route, Routes } from 'react-router-dom';

import AuthFormSwitcher from "./auth/AuthFormSwitcher/AuthFormSwitcher";
import ProtectedRoute from "./auth/ProtectedRoute"
import Profile from "./pages/Profile";
import Verify from "./pages/Verify";
import RatingTable from "./pages/RatingTable";
import Shop from "./pages/Shop"
import GamePage from "./pages/GamePage";
import GameSize from "./pages/GameSize";
import Index from  "./pages/Index";


export default function App(props) {
  return (
      <AppTheme {...props}>
          <CssBaseline enableColorScheme />

          <BrowserRouter>

              <AppAppBar />

              <Routes>
                  <Route path="/auth" element={<AuthFormSwitcher />} />
                  <Route path="/" element={<Index />} />

                  <Route path="/rating" element={<ProtectedRoute element={RatingTable} />} />

                  <Route path="/game">
                      <Route path='play' element={<ProtectedRoute element={GamePage} />} />
                      <Route path='size' element={<ProtectedRoute element={GameSize} />} />
                  </Route>
                  <Route path="/verify/:token" element={<Verify />} />
                  <Route path="/profile" element={<ProtectedRoute element={Profile} />} />
                  <Route path="/shop" element={<Shop />} >
                      <Route path="boosts/:id/buy" element={<Shop />} />
                  </Route>

              </Routes>

              <Footer />

          </BrowserRouter>

      </AppTheme>
  )
}
