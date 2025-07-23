import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  Container,
  Typography,
  Box,
  CircularProgress,
  Button,
  Alert,
  Paper
} from '@mui/material';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline';

const Verify = () => {
  const { token } = useParams();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    const verifyEmail = async () => {
      try {
        const response = await fetch('/api/v2/verify', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ token }),
        });

        if (response.ok) {
          setSuccess(true);
        } else {
          const data = await response.json();
          setError(data.message || 'Ошибка подтверждения email');
        }
      } catch (err) {
        setError('Произошла ошибка при соединении с сервером');
      } finally {
        setLoading(false);
      }
    };

    verifyEmail();
  }, [token]);

  const handleGoToGame = () => {
    navigate('/game/size');
  };

  const handleMain = () => {
    navigate('/');
  };

  return (
      <Box
            sx={(theme) => ({
                width: '100%',
                backgroundRepeat: 'no-repeat',
                backgroundImage:
                    'radial-gradient(ellipse 80% 50% at 50% -20%, hsl(210, 100%, 90%), transparent)',
                ...theme.applyStyles('dark', {
                    backgroundImage:
                        'radial-gradient(ellipse 80% 50% at 50% -20%, hsl(210, 100%, 16%), transparent)',
                }),
            })}
        >
            <Container
                sx={{
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    pt: { xs: 14, sm: 20 },
                    pb: { xs: 8, sm: 12 },
                }}
            >

    <Container maxWidth="sm" sx={{ mt: 8 }}>
      <Paper elevation={3} sx={{ p: 4, textAlign: 'center' }}>
        {loading ? (
          <>
            <CircularProgress size={60} sx={{ mb: 3 }} />
            <Typography variant="h6" gutterBottom>
              Идёт подтверждение email...
            </Typography>
          </>
        ) : success ? (
          <>
            <CheckCircleOutlineIcon sx={{ fontSize: 60, color: 'success.main', mb: 2 }} />
            <Typography variant="h4" gutterBottom sx={{ color: 'success.main' }}>
              Email успешно подтверждён!
            </Typography>
            <Typography variant="body1" sx={{ mb: 3 }}>
              Спасибо за подтверждение email в игре SeaBattle.
            </Typography>
            <Button
              variant="contained"
              size="large"
              onClick={handleGoToGame}
              sx={{ mt: 2 }}
            >
              Начать играть
            </Button>
          </>
        ) : (
          <>
            <ErrorOutlineIcon sx={{ fontSize: 60, color: 'error.main', mb: 2 }} />
            <Typography variant="h5" gutterBottom sx={{ color: 'error.main' }}>
              Ошибка подтверждения
            </Typography>
            <Alert severity="error" sx={{ mb: 3 }}>
              {error || 'Неизвестная ошибка'}
            </Alert>
            <Button
              variant="outlined"
              onClick={handleMain}
              sx={{ mt: 2 }}
            >
              Вернуться на главную
            </Button>
          </>
        )}
      </Paper>
    </Container>

            </Container>
      </Box>
  );
};

export default Verify;