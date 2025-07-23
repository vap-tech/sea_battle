import React, { useState } from 'react';
import {
  Container,
  Typography,
  Box,
  Button,
  Alert,
  Paper,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  CircularProgress
} from '@mui/material';
import SendIcon from '@mui/icons-material/Send';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline';

const ResendVerification = () => {
  const [openDialog, setOpenDialog] = useState(false);
  const [status, setStatus] = useState(null);
  const [error, setError] = useState(null);

  const handleResendClick = () => {
    setOpenDialog(true);
  };

  const handleConfirmResend = async () => {
    setOpenDialog(false);
    setStatus('loading');
    setError(null);

    try {
      const response = await fetch('/api/v2/verification_email', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include'
      });

      if (response.ok) {
        setStatus('success');
      } else {
        const data = await response.json();
        throw new Error(data.message || 'Ошибка при отправке письма');
      }
    } catch (err) {
      setStatus('error');
      setError(err.message);
    }
  };

  const handleDialogClose = () => {
    setOpenDialog(false);
  };

  return (
    <Container maxWidth="sm" sx={{ mt: 8 }}>
      <Paper elevation={3} sx={{ p: 4, textAlign: 'center' }}>
        <Typography variant="h5" gutterBottom>
          Подтверждение email
        </Typography>

        <Typography variant="body1" sx={{ mb: 3 }}>
          Не получили письмо с подтверждением? Отправить повторно.
        </Typography>

        {status === 'loading' && (
          <>
            <CircularProgress size={60} sx={{ mb: 3 }} />
            <Typography variant="h6">
              Отправка письма...
            </Typography>
          </>
        )}

        {status === 'success' && (
          <>
            <CheckCircleOutlineIcon sx={{ fontSize: 60, color: 'success.main', mb: 2 }} />
            <Typography variant="h6" sx={{ color: 'success.main', mb: 2 }}>
              Письмо отправлено!
            </Typography>
            <Alert severity="success" sx={{ mb: 2 }}>
              Проверьте вашу почту и следуйте инструкциям в письме
            </Alert>
          </>
        )}

        {status === 'error' && (
          <>
            <ErrorOutlineIcon sx={{ fontSize: 60, color: 'error.main', mb: 2 }} />
            <Typography variant="h6" sx={{ color: 'error.main', mb: 2 }}>
              Ошибка отправки
            </Typography>
            <Alert severity="error" sx={{ mb: 2 }}>
              {error || 'Произошла ошибка при отправке письма'}
            </Alert>
          </>
        )}

        {!status && (
          <Button
            variant="contained"
            size="large"
            startIcon={<SendIcon />}
            onClick={handleResendClick}
            sx={{ mt: 2 }}
          >
            Отправить повторно
          </Button>
        )}

        {/* Диалог подтверждения */}
        <Dialog open={openDialog} onClose={handleDialogClose}>
          <DialogTitle>Подтверждение</DialogTitle>
          <DialogContent>
            <DialogContentText>
              Отправить письмо с подтверждением на ваш email?
            </DialogContentText>
          </DialogContent>
          <DialogActions>
            <Button onClick={handleDialogClose}>Отмена</Button>
            <Button
              onClick={handleConfirmResend}
              color="primary"
              autoFocus
            >
              Отправить
            </Button>
          </DialogActions>
        </Dialog>
      </Paper>
    </Container>
  );
};

export default ResendVerification;