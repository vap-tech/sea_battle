import React from 'react';
import { CircularProgress, Box, Typography } from '@mui/material';

function CircularProgressWithLabel({ initialTime, onTimeEnd }) {
  const [remainingTime, setRemainingTime] = React.useState(initialTime);

  React.useEffect(() => {
    const timer = setInterval(() => {
      setRemainingTime((prev) => {
        if (prev <= 1) {
          clearInterval(timer);
          onTimeEnd();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(timer);
  }, [onTimeEnd]);

  const progress = (remainingTime / initialTime) * 100;
  const minutes = Math.floor(remainingTime / 60);
  const seconds = remainingTime % 60;

  return (
    <Box sx={{ position: 'relative', display: 'inline-flex' }}>
      <CircularProgress variant="determinate" value={progress} />
      <Box
        sx={{
          top: 0,
          left: 0,
          bottom: 0,
          right: 0,
          position: 'absolute',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Typography
          variant="caption"
          component="div"
          sx={{ color: 'text.secondary' }}
        >
          {`${minutes}:${seconds < 10 ? '0' : ''}${seconds}`}
        </Typography>
      </Box>
    </Box>
  );
}

export default function CircularWithValueLabel({ onTimeEnd }) {
  const initialTime = 300; // 5 минут в секундах

  return (
    <CircularProgressWithLabel
      initialTime={initialTime}
      onTimeEnd={onTimeEnd}
    />
  );
}