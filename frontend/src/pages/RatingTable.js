import React, { useEffect, useState } from 'react';
import axios from 'axios';
import {
  Container,
  Paper,
  Box,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  CircularProgress,
  Typography,
  Chip,
  Avatar,
  LinearProgress,
  useTheme
} from '@mui/material';
import {
  MilitaryTech as MilitaryTechIcon,
  EmojiEvents as TrophyIcon,
  Person as PersonIcon
} from '@mui/icons-material';

const RatingTable = () => {
  const [rating, setRating] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const theme = useTheme();

  useEffect(() => {
    async function fetchRating() {
      try {
        const response = await axios.get('/api/v2/rank');

        if (response.status === 200 && Array.isArray(response.data.rating)) {
          setRating(response.data.rating);
        } else {
          throw new Error("Некорректная структура ответа");
        }
        setLoading(false);
      } catch (err) {
        console.error(err.message);
        setError(true);
        setLoading(false);
      }
    }

    fetchRating();
  }, []);

  if (loading) return (
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
      <Paper elevation={3} sx={{ p: 3, textAlign: 'center' }}>
        <Box display="flex" justifyContent="center" alignItems="center" height={300}>
          <CircularProgress size={80} thickness={4} />
        </Box>
      </Paper>
    </Container>

            </Container></Box>
  );

  if (error) return (
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
      <Paper elevation={3} sx={{ p: 3, textAlign: 'center' }}>
        <Typography variant="h5" color="error" gutterBottom>
          Ошибка при загрузке рейтинга
        </Typography>
        <Typography color="text.secondary">
          Пожалуйста, попробуйте обновить страницу позже
        </Typography>
      </Paper>
    </Container>

            </Container></Box>
  );

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
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
          <TrophyIcon color="primary" sx={{ fontSize: 40, mr: 2 }} />
          <Typography variant="h4" component="h1">
            Рейтинг игроков
          </Typography>
        </Box>

        <TableContainer>
          <Table aria-label="Рейтинг игроков">
            <TableHead>
              <TableRow sx={{ backgroundColor: theme.palette.mode === 'dark' ? '#1E1E1E' : '#f5f5f5' }}>
                <TableCell sx={{ fontWeight: 'bold', width: '10%' }}>#</TableCell>
                <TableCell sx={{ fontWeight: 'bold', width: '50%' }}>Игрок</TableCell>
                <TableCell sx={{ fontWeight: 'bold', width: '20%' }}>Очки</TableCell>
                <TableCell sx={{ fontWeight: 'bold', width: '20%' }}>Ранг</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {rating.map((player, index) => (
                <TableRow
                  key={`${player.nickname}-${index}`}
                  hover
                  sx={{ '&:nth-of-type(odd)': { backgroundColor: theme.palette.action.hover } }}
                >
                  <TableCell>
                    <Chip
                      label={player.position}
                      color={index < 3 ? 'primary' : 'default'}
                      variant={index < 3 ? 'filled' : 'outlined'}
                    />
                  </TableCell>
                  <TableCell>
                    <Box sx={{ display: 'flex', alignItems: 'center' }}>
                      <Avatar
                        src={player.avatar || '/default-avatar.jpg'}
                        sx={{ width: 36, height: 36, mr: 2 }}
                      >
                        <PersonIcon />
                      </Avatar>
                      <Typography>
                        {player.nickname}
                      </Typography>
                    </Box>
                  </TableCell>
                  <TableCell>
                    <Box sx={{ display: 'flex', alignItems: 'center' }}>
                      <LinearProgress
                        value={Math.min(100, player.score / 1000 * 100)}
                        variant="determinate"
                        sx={{
                          width: '100%',
                          height: 8,
                          borderRadius: 4,
                          mr: 2
                        }}
                      />
                      {player.score}
                    </Box>
                  </TableCell>
                  <TableCell>
                    <Chip
                      icon={<MilitaryTechIcon />}
                      label={player.rank}
                      color="secondary"
                      size="small"
                    />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>

        <Box sx={{ mt: 3, display: 'flex', justifyContent: 'flex-end' }}>
          <Typography variant="caption" color="text.secondary">
            Обновлено: {new Date().toLocaleString()}
          </Typography>
        </Box>
      </Paper>
    </Container>

            </Container></Box>
  );
}

export default RatingTable;