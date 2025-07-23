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
  CircularProgress,
  TextField
} from '@mui/material';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline';
import LockResetIcon from '@mui/icons-material/LockReset';

const ChangePassword = () => {
  const [openDialog, setOpenDialog] = useState(false);
  const [status, setStatus] = useState(null);
  const [error, setError] = useState(null);
  const [passwords, setPasswords] = useState({
    oldPassword: '',
    newPassword: '',
    confirmPassword: ''
  });
  const [errors, setErrors] = useState({});

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setPasswords(prev => ({ ...prev, [name]: value }));
    // Очищаем ошибку при изменении поля
    if (errors[name]) {
      setErrors(prev => ({ ...prev, [name]: '' }));
    }
  };

  const validate = () => {
    const newErrors = {};

    if (!passwords.oldPassword) {
      newErrors.oldPassword = 'Введите текущий пароль';
    }

    if (!passwords.newPassword) {
      newErrors.newPassword = 'Введите новый пароль';
    } else if (passwords.newPassword.length < 6) {
      newErrors.newPassword = 'Пароль должен быть не менее 6 символов';
    }

    if (passwords.newPassword !== passwords.confirmPassword) {
      newErrors.confirmPassword = 'Пароли не совпадают';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleChangePasswordClick = () => {
    if (validate()) {
      setOpenDialog(true);
    }
  };

  const handleConfirmChange = async () => {
    setOpenDialog(false);
    setStatus('loading');
    setError(null);

    try {
      const response = await fetch('/api/v2/change_password', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          old_password: passwords.oldPassword,
          new_password: passwords.newPassword
        }),
      });

      if (response.ok) {
        setStatus('success');
        // Очищаем поля после успешной смены
        setPasswords({
          oldPassword: '',
          newPassword: '',
          confirmPassword: ''
        });
      } else {
        const data = await response.json();
        throw new Error(data.message || 'Ошибка при смене пароля');
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
      <Paper elevation={3} sx={{ p: 4 }}>
        <Typography variant="h5" gutterBottom sx={{ textAlign: 'center' }}>
          Смена пароля
        </Typography>

        <Box component="form" sx={{ mt: 3 }}>
          <TextField
            fullWidth
            margin="normal"
            label="Текущий пароль"
            name="oldPassword"
            type="password"
            value={passwords.oldPassword}
            onChange={handleInputChange}
            error={!!errors.oldPassword}
            helperText={errors.oldPassword}
          />

          <TextField
            fullWidth
            margin="normal"
            label="Новый пароль"
            name="newPassword"
            type="password"
            value={passwords.newPassword}
            onChange={handleInputChange}
            error={!!errors.newPassword}
            helperText={errors.newPassword}
          />

          <TextField
            fullWidth
            margin="normal"
            label="Подтвердите новый пароль"
            name="confirmPassword"
            type="password"
            value={passwords.confirmPassword}
            onChange={handleInputChange}
            error={!!errors.confirmPassword}
            helperText={errors.confirmPassword}
          />

          {status === 'loading' && (
            <Box sx={{ textAlign: 'center', mt: 3 }}>
              <CircularProgress size={60} />
              <Typography variant="h6" sx={{ mt: 2 }}>
                Меняем пароль...
              </Typography>
            </Box>
          )}

          {status === 'success' && (
            <Box sx={{ textAlign: 'center', mt: 3 }}>
              <CheckCircleOutlineIcon sx={{ fontSize: 60, color: 'success.main' }} />
              <Typography variant="h6" sx={{ color: 'success.main', mt: 2 }}>
                Пароль успешно изменён!
              </Typography>
              <Alert severity="success" sx={{ mt: 2 }}>
                Теперь вы можете использовать новый пароль для входа
              </Alert>
            </Box>
          )}

          {status === 'error' && (
            <Box sx={{ textAlign: 'center', mt: 3 }}>
              <ErrorOutlineIcon sx={{ fontSize: 60, color: 'error.main' }} />
              <Typography variant="h6" sx={{ color: 'error.main', mt: 2 }}>
                Ошибка смены пароля
              </Typography>
              <Alert severity="error" sx={{ mt: 2 }}>
                {error || 'Произошла ошибка при смене пароля'}
              </Alert>
            </Box>
          )}

          {!status && (
            <Box sx={{ textAlign: 'center', mt: 3 }}>
              <Button
                variant="contained"
                size="large"
                startIcon={<LockResetIcon />}
                onClick={handleChangePasswordClick}
                sx={{ mt: 2 }}
              >
                Сменить пароль
              </Button>
            </Box>
          )}
        </Box>

        {/* Диалог подтверждения */}
        <Dialog open={openDialog} onClose={handleDialogClose}>
          <DialogTitle>Подтверждение смены пароля</DialogTitle>
          <DialogContent>
            <DialogContentText>
              Вы уверены, что хотите сменить пароль?
            </DialogContentText>
          </DialogContent>
          <DialogActions>
            <Button onClick={handleDialogClose}>Отмена</Button>
            <Button
              onClick={handleConfirmChange}
              color="primary"
              autoFocus
            >
              Подтвердить
            </Button>
          </DialogActions>
        </Dialog>
      </Paper>
    </Container>
  );
};

export default ChangePassword;