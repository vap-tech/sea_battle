import React from 'react';
import {Container, Paper, Box, Grid, Typography, Divider, Avatar, List, ListItem,
  ListItemIcon, ListItemText, Chip, LinearProgress } from '@mui/material';
import ResendVerification from './components/ResendVerification';
import ChangePassword from './components/ChangePassword';
import DepositBalance from "./components/DepositBalance";
import {
  MilitaryTech as MilitaryTechIcon,
  EmojiEvents as EmojiEventsIcon,
  Timer as TimerIcon,
  CheckCircle as CheckCircleIcon,
  Cancel as CancelIcon
} from '@mui/icons-material';

const Profile = () => {
  // Заглушка для статистики (замените на реальные данные из API)
  const userStats = {
    avatar: '/default-avatar.jpg',
    nickname: localStorage.getItem('nickname') || 'МорскойВолк',
    rank: 'Капитан',
    gamesPlayed: 42,
    wins: 28,
    losses: 14,
    winRate: 66.7,
    averageTime: '15:23',
    achievements: ['Первый бой', 'Серия побед', 'Неуязвимый']
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

    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Paper elevation={3} sx={{ p: 3 }}>
        <Typography variant="h4" gutterBottom sx={{ pb: 2 }}>
          Мой профиль
        </Typography>

        <Grid container spacing={4}>
          {/* Левая колонка - Статистика */}
          <Grid item xs={12} md={4}>
            <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', mb: 3 }}>
              <Avatar
                src={userStats.avatar}
                sx={{ width: 120, height: 120, mb: 2 }}
              />
              <Typography variant="h5">{userStats.nickname}</Typography>
              <Chip
                label={userStats.rank}
                color="primary"
                size="small"
                sx={{ mt: 1 }}
                icon={<MilitaryTechIcon />}
              />
            </Box>

            <List dense>
              <ListItem>
                <ListItemIcon>
                  <EmojiEventsIcon color="primary" />
                </ListItemIcon>
                <ListItemText
                  primary="Игр сыграно"
                  secondary={userStats.gamesPlayed}
                />
              </ListItem>
              <ListItem>
                <ListItemIcon>
                  <CheckCircleIcon color="success" />
                </ListItemIcon>
                <ListItemText
                  primary="Побед"
                  secondary={userStats.wins}
                />
              </ListItem>
              <ListItem>
                <ListItemIcon>
                  <CancelIcon color="error" />
                </ListItemIcon>
                <ListItemText
                  primary="Поражений"
                  secondary={userStats.losses}
                />
              </ListItem>
              <ListItem>
                <ListItemIcon>
                  <TimerIcon color="info" />
                </ListItemIcon>
                <ListItemText
                  primary="Среднее время"
                  secondary={userStats.averageTime}
                />
              </ListItem>
            </List>

            <Box sx={{ mt: 2 }}>
              <Typography variant="body2" color="text.secondary">
                Процент побед
              </Typography>
              <LinearProgress
                variant="determinate"
                value={userStats.winRate}
                sx={{ height: 10, borderRadius: 5, mt: 1 }}
              />
              <Typography variant="body2" sx={{ textAlign: 'right', mt: 1 }}>
                {userStats.winRate}%
              </Typography>
            </Box>

            <Box sx={{ mt: 3 }}>
              <Typography variant="subtitle2" gutterBottom>
                Достижения:
              </Typography>
              <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                {userStats.achievements.map((ach, index) => (
                  <Chip
                    key={index}
                    label={ach}
                    size="small"
                    color="secondary"
                  />
                ))}
              </Box>
            </Box>
          </Grid>

          {/* Правая колонка - Настройки */}
          <Grid item xs={12} md={8}>
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              {/* Компонент подтверждения email */}
              <Box>
                <Typography variant="h6" gutterBottom>
                  Подтверждение email
                </Typography>
                <Divider sx={{ mb: 2 }} />
                <ResendVerification />
              </Box>

              {/* Компонент смены пароля */}
              <Box>
                <Typography variant="h6" gutterBottom>
                  Безопасность аккаунта
                </Typography>
                <Divider sx={{ mb: 2 }} />
                <ChangePassword />
              </Box>

              {/* Компонент пополнения баланса */}
              <Box>
                <Typography variant="h6" gutterBottom>
                  Пополнение баланса
                </Typography>
                <Divider sx={{ mb: 2 }} />
                <DepositBalance />
              </Box>

              {/* Место для будущих компонентов */}
              <Box>
                <Typography variant="h6" gutterBottom>
                  Настройки уведомлений
                </Typography>
                <Divider sx={{ mb: 2 }} />
                <Typography color="text.secondary">
                  Раздел в разработке
                </Typography>
              </Box>
            </Box>
          </Grid>
        </Grid>
      </Paper>
    </Container>

            </Container></Box>

  );
};

export default Profile;