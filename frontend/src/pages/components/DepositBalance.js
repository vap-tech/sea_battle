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
import PaymentIcon from '@mui/icons-material/Payment';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline';

const DepositBalance = () => {
  const [openDialog, setOpenDialog] = useState(false);
  const [status, setStatus] = useState(null);
  const [error, setError] = useState(null);
  const [responseData, setResponseData] = useState(null);
  const [amount, setAmount] = useState('');
  const [amountError, setAmountError] = useState('');

  const handleDepositClick = () => {
    if (!amount) {
      setAmountError('Введите сумму');
      return;
    }
    if (isNaN(amount) || Number(amount) <= 0) {
      setAmountError('Введите корректную сумму');
      return;
    }
    setOpenDialog(true);
  };

  const handleConfirmDeposit = async () => {
    setOpenDialog(false);
    setStatus('loading');
    setError(null);
    setResponseData(null);

    try {
      const response = await fetch('/api/v2/balance/deposit', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({ amount: Number(amount) })
      });

      const data = await response.json();

      if (response.ok) {
        setStatus('success');
        setResponseData(data);
      } else {
        throw new Error(data.message || 'Ошибка при пополнении баланса');
      }
    } catch (err) {
      setStatus('error');
      setError(err.message);
    }
  };

  const handleDialogClose = () => {
    setOpenDialog(false);
  };

  const handleAmountChange = (e) => {
    setAmount(e.target.value);
    if (e.target.value && !isNaN(e.target.value) && Number(e.target.value) > 0) {
      setAmountError('');
    }
  };

  return (
    <Container maxWidth="sm" sx={{ mt: 8 }}>
      <Paper elevation={3} sx={{ p: 4, textAlign: 'center' }}>
        <Typography variant="h5" gutterBottom>
          Пополнение баланса
        </Typography>

        <Typography variant="body1" sx={{ mb: 3 }}>
          Введите сумму для пополнения вашего баланса
        </Typography>

        <TextField
          label="Сумма"
          variant="outlined"
          type="number"
          value={amount}
          onChange={handleAmountChange}
          error={!!amountError}
          helperText={amountError}
          sx={{ mb: 3, width: '100%' }}
          InputProps={{ inputProps: { min: 0.01, step: 0.01 } }}
        />

        {status === 'loading' && (
          <>
            <CircularProgress size={60} sx={{ mb: 3 }} />
            <Typography variant="h6">
              Пополнение баланса...
            </Typography>
          </>
        )}

        {status === 'success' && (
          <>
            <CheckCircleOutlineIcon sx={{ fontSize: 60, color: 'success.main', mb: 2 }} />
            <Typography variant="h6" sx={{ color: 'success.main', mb: 2 }}>
              Баланс успешно пополнен!
            </Typography>
            <Alert severity="info" sx={{ mb: 2 }}>
              <pre>{JSON.stringify(responseData, null, 2)}</pre>
            </Alert>
          </>
        )}

        {status === 'error' && (
          <>
            <ErrorOutlineIcon sx={{ fontSize: 60, color: 'error.main', mb: 2 }} />
            <Typography variant="h6" sx={{ color: 'error.main', mb: 2 }}>
              Ошибка пополнения
            </Typography>
            <Alert severity="error" sx={{ mb: 2 }}>
              {error || 'Произошла ошибка при пополнении баланса'}
            </Alert>
          </>
        )}

        {!status && (
          <Button
            variant="contained"
            size="large"
            startIcon={<PaymentIcon />}
            onClick={handleDepositClick}
            sx={{ mt: 2 }}
            disabled={!amount || !!amountError}
          >
            Пополнить баланс
          </Button>
        )}

        {/* Диалог подтверждения */}
        <Dialog open={openDialog} onClose={handleDialogClose}>
          <DialogTitle>Подтверждение</DialogTitle>
          <DialogContent>
            <DialogContentText>
              Вы действительно хотите пополнить баланс на {amount}?
            </DialogContentText>
          </DialogContent>
          <DialogActions>
            <Button onClick={handleDialogClose}>Отмена</Button>
            <Button
              onClick={handleConfirmDeposit}
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

export default DepositBalance;