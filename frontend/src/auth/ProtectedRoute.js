import React, { useState, useEffect } from 'react';
import { Navigate } from 'react-router-dom';
import {CircularProgress, Typography} from "@mui/material";
import Box from "@mui/material/Box";

async function checkAuth() {
  try {
    const response = await fetch('/api/v2/me', {
      method: 'POST',
      credentials: 'include',
    });

    if (response.ok) {
      const data = await response.json();
      return { isAuthenticated: true, user: data };
    }

    if (response.status === 401) {
      // Пробуем обновить токен
      const refreshResponse = await fetch('/api/v2/refresh_auth', {
        method: 'POST',
        credentials: 'include',
      });

      if (refreshResponse.ok) {
        // После успешного обновления проверяем снова
        const retryResponse = await fetch('/api/v2/me', {
          method: 'POST',
          credentials: 'include',
        });

        if (retryResponse.ok) {
          const data = await retryResponse.json();
          return { isAuthenticated: true, user: data };
        }
      }
    }

    return { isAuthenticated: false };
  } catch (error) {
    console.error('Auth check failed:', error);
    return { isAuthenticated: false };
  }
}

export default function ProtectedRoute({ element: Element, ...rest }) {
  const [authState, setAuthState] = useState({
    isLoading: true,
    isAuthenticated: false,
    user: null,
  });

  useEffect(() => {
    let isMounted = true;

    async function verifyAuth() {
      const { isAuthenticated, user } = await checkAuth();

      if (isMounted) {
        setAuthState({
          isLoading: false,
          isAuthenticated,
          user,
        });
      }
    }

    verifyAuth().then(() => {console.log("Verify Auth Ok")});

    return () => {
      isMounted = false;
    };
  }, []);

  if (authState.isLoading) {
    return <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
        <CircularProgress color="inherit" />
        <Typography variant="body1">
            Loading...
        </Typography>
    </Box> // Красивый лоадер
  }

  if (!authState.isAuthenticated) {
    return <Navigate to="/auth" replace />;
  }

  if (authState.user?.name && authState.user?.rank) {
    localStorage.setItem("nickname", authState.user?.name);
    localStorage.setItem("rank", authState.user?.rank);
  }

  return <Element {...rest} user={authState.user} />;
}
