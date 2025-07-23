import * as React from 'react';
import { styled, alpha } from '@mui/material/styles';
import Box from '@mui/material/Box';
import AppBar from '@mui/material/AppBar';
import Toolbar from '@mui/material/Toolbar';
import Button from '@mui/material/Button';
import Container from '@mui/material/Container';
import Badge from '@mui/material/Badge';
import ColorModeIconDropdown from '../../shared-theme/ColorModeIconDropdown';
import SiaBattleIcon from './SiaBattleIcon';
import AnchorIcon from '@mui/icons-material/Anchor';
import GpsFixedIcon from '@mui/icons-material/GpsFixed';
import Stack from "@mui/material/Stack";
import {useNavigate} from "react-router-dom";
import {useState, useEffect} from "react";
import {Typography} from "@mui/material";


const StyledToolbar = styled(Toolbar)(({ theme }) => ({
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  flexShrink: 0,
  borderRadius: `calc(${theme.shape.borderRadius}px + 8px)`,
  backdropFilter: 'blur(24px)',
  border: '1px solid',
  borderColor: (theme.vars || theme).palette.divider,
  backgroundColor: theme.vars
    ? `rgba(${theme.vars.palette.background.defaultChannel} / 0.4)`
    : alpha(theme.palette.background.default, 0.4),
  boxShadow: (theme.vars || theme).shadows[1],
  padding: '8px 12px',
}));

export default function AppAppBar() {

  const navigate = useNavigate();
  const [balance, setBalance] = useState(null);
  const nickname = localStorage.getItem('nickname');

  useEffect(() => {
    const fetchBalance = async () => {
      try {
        const response = await fetch('/api/v2/balance/current', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          credentials: 'include'
        });

        if (!response.ok) {
          throw new Error('Network response was not ok');
        }

        const data = await response.json();
        if (data.success) {
          setBalance(data.current_balance);
        }
      } catch (error) {
        console.error('Error fetching balance:', error);
      }
    };

    fetchBalance();
  }, []);

  const startRating = (event) => {
        event.preventDefault();
        navigate(`/rating`);
    };

  const startGame = (event) => {
        event.preventDefault();
        navigate(`/game/size`);
    };

  const startShop = (event) => {
        event.preventDefault();
        navigate(`/shop`);
    };

  const handleAuthClick = (event) => {
    event.preventDefault();
    if (nickname) {
      navigate('/profile');
    } else {
      navigate('/auth');
    }
  };

  return (
    <AppBar
      position="fixed"
      enableColorOnDark
      sx={{
        boxShadow: 0,
        bgcolor: 'transparent',
        backgroundImage: 'none',
        mt: 'calc(var(--template-frame-height, 0px) + 28px)',
      }}
    >
      <Container maxWidth="lg">
        <StyledToolbar variant="dense" disableGutters>
          <Box sx={{ flexGrow: 1, display: 'flex', alignItems: 'center', px: 0 }}>
            <SiaBattleIcon />
            {balance !== null && (
              <Typography variant="body2" color={"success"} sx={{ mr: 2, ml: 2, fontWeight: 'bold' }}>
                {balance} ₽
              </Typography>
            )}
            <Stack spacing={2} direction="row">
              <Badge badgeContent={4} color="primary" anchorOrigin={{vertical: 'bottom', horizontal: 'right'}}>
              <AnchorIcon color="action"  />
              </Badge>
            <Badge badgeContent={6} color="primary" anchorOrigin={{vertical: 'bottom', horizontal: 'right'}}>
              <GpsFixedIcon color="action" />
            </Badge>
            </Stack>
          </Box>
          <Box
            sx={{
              display: { xs: 'none', md: 'flex' },
              gap: 1,
              alignItems: 'center',
            }}
          >
            <Button color="primary" variant="text" size="small" onClick={startGame}>
              Игра
            </Button>
            <Button color="primary" variant="text" size="small" onClick={startRating}>
              Рейтинг
            </Button>
            <Button color="primary" variant="text" size="small" onClick={startShop}>
              Магазин
            </Button>
            <Button color="primary" variant="contained" size="small" onClick={handleAuthClick}>
              {nickname ? nickname : 'Войти'}
            </Button>
            <ColorModeIconDropdown />
          </Box>
        </StyledToolbar>
      </Container>
    </AppBar>
  );
}
