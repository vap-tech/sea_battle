import React, { useState, useEffect } from 'react';
import {
  Container,
  Paper,
  Box,
  Typography,
  Grid,
  Card,
  CardContent,
  CardActions,
  Button,
  Chip,
  CircularProgress,
  Alert,
  Tabs,
  Tab,
  Collapse,
  IconButton,
  Tooltip
} from '@mui/material';
import axios from 'axios';
import {
  LocalOffer as OfferIcon,
  ShoppingCart as CartIcon,
  Info as InfoIcon,
  Category as CategoryIcon,
  ExpandMore as ExpandMoreIcon,
  ExpandLess as ExpandLessIcon
} from '@mui/icons-material';

const Shop = () => {
  const [boosts, setBoosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState('all');
  const [pagination, setPagination] = useState({
    lastId: null,
    limit: 6,
    hasMore: true
  });
  const [expandedBoost, setExpandedBoost] = useState(null);

  const fetchBoosts = async (reset = false) => {
    try {
      setLoading(true);
      const params = new URLSearchParams();

      if (filter !== 'all') params.append('type', filter);
      if (!reset && pagination.lastId) params.append('last_id', pagination.lastId);
      params.append('limit', pagination.limit);

      const response = await axios.get('/api/v2/shop/boosts', { params });

      if (reset) {
        setBoosts(response.data.boosts);
      } else {
        setBoosts(prev => [...prev, ...response.data.boosts]);
      }

      setPagination({
        lastId: response.data.next_last_id || null,
        limit: pagination.limit,
        hasMore: Boolean(response.data.next_last_id)
      });

      setError(null);
    } catch (err) {
      setError(err.response?.data?.message || 'Ошибка загрузки магазина');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchBoosts(true);
  }, [filter]);

  const handleFilterChange = (event, newValue) => {
    setFilter(newValue);
  };

  const handleLoadMore = () => {
    if (pagination.hasMore && !loading) {
      fetchBoosts();
    }
  };

  const handleBuy = async (id) => {
  try {
    console.log('Покупка буста:', id);

    const response = await fetch(`/api/v2/shop/boosts/${id}/buy`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
      },
      // body: JSON.stringify({ someData: 'value' })
    });

    if (!response.ok) { throw new Error(`HTTP error! status: ${response.status}`);  }

    const data = await response.json();
    if (data.success) { console.log('Покупка успешна:', data); }
    else { console.error('Ошибка покупки:', data.message || 'Неизвестная ошибка'); }

  } catch (error) {
    console.error('Ошибка при выполнении запроса:', error);
    // Можно добавить уведомление об ошибке
    // Например: showErrorNotification('Ошибка сети при попытке покупки');
  }
};

  const toggleExpand = (id) => {
    setExpandedBoost(expandedBoost === id ? null : id);
  };

  const parseGameEffect = (effectString) => {
    try {
      return JSON.parse(effectString);
    } catch {
      return { value: 'N/A', duration_min: 'N/A' };
    }
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
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
          <OfferIcon color="primary" sx={{ fontSize: 40, mr: 2 }} />
          <Typography variant="h4" component="h1">
            Магазин бустов
          </Typography>
        </Box>

        <Tabs
          value={filter}
          onChange={handleFilterChange}
          variant="scrollable"
          scrollButtons="auto"
          sx={{ mb: 3 }}
        >
          <Tab label="Все" value="all" icon={<CategoryIcon />} iconPosition="start" />
          <Tab label="Урон" value="damage" icon={<CategoryIcon />} iconPosition="start" />
          <Tab label="Защита" value="defense" icon={<CategoryIcon />} iconPosition="start" />
          <Tab label="Скорость" value="speed" icon={<CategoryIcon />} iconPosition="start" />
          <Tab label="Опыт" value="xp" icon={<CategoryIcon />} iconPosition="start" />
          <Tab label="Ресурсы" value="resource" icon={<CategoryIcon />} iconPosition="start" />
          <Tab label="Специальные" value="special" icon={<CategoryIcon />} iconPosition="start" />
          <Tab label="Командные" value="team" icon={<CategoryIcon />} iconPosition="start" />
        </Tabs>

        {error && (
          <Alert severity="error" sx={{ mb: 3 }}>
            {error}
          </Alert>
        )}

        {loading && boosts.length === 0 ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
            <CircularProgress size={60} />
          </Box>
        ) : (
          <>
            <Grid container spacing={3}>
              {boosts.map((boost) => {
                const gameEffect = parseGameEffect(boost.game_effect);
                const isExpanded = expandedBoost === boost.id;

                return (
                  <Grid item xs={12} sm={6} md={4} lg={3} key={boost.id}>
                    <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
                      <CardContent sx={{ flexGrow: 1 }}>
                        <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
                          <Typography gutterBottom variant="h6" component="h3">
                            {boost.name}
                          </Typography>
                          <Tooltip title={isExpanded ? "Скрыть детали" : "Показать детали"}>
                            <IconButton
                              size="small"
                              onClick={() => toggleExpand(boost.id)}
                              aria-expanded={isExpanded}
                              aria-label="Показать детали"
                            >
                              {isExpanded ? <ExpandLessIcon /> : <ExpandMoreIcon />}
                            </IconButton>
                          </Tooltip>
                        </Box>

                        <Chip
                          label={boost.type}
                          color="secondary"
                          size="small"
                          sx={{ mb: 2 }}
                        />

                        <Typography variant="body2" color="text.secondary" paragraph>
                          {boost.description}
                        </Typography>

                        <Collapse in={isExpanded}>
                          <Box sx={{
                            mt: 2,
                            p: 2,
                            backgroundColor: theme => theme.palette.mode === 'dark' ? 'rgba(255, 255, 255, 0.08)' : 'rgba(0, 0, 0, 0.04)',
                            borderRadius: 1
                          }}>
                            <Typography variant="subtitle2" gutterBottom>
                              Игровой эффект:
                            </Typography>
                            <Box component="pre" sx={{
                              fontSize: '0.8rem',
                              whiteSpace: 'pre-wrap',
                              wordBreak: 'break-word',
                              fontFamily: 'monospace',
                              m: 0
                            }}>
                              {JSON.stringify(gameEffect, null, 2)}
                            </Box>
                          </Box>
                        </Collapse>

                        <Box sx={{ display: 'flex', alignItems: 'center', mt: 'auto' }}>
                          <Typography variant="h6" color="primary">
                            ${boost.price}
                          </Typography>
                          {boost.discount && (
                            <Chip
                              label={`-${boost.discount}%`}
                              color="error"
                              size="small"
                              sx={{ ml: 1 }}
                            />
                          )}
                        </Box>
                      </CardContent>
                      <CardActions sx={{ justifyContent: 'space-between' }}>
                        <Tooltip title="Подробнее об эффекте">
                          <Button
                            size="small"
                            startIcon={<InfoIcon />}
                            onClick={() => toggleExpand(boost.id)}
                          >
                            Эффект
                          </Button>
                        </Tooltip>
                        <Button
                          size="small"
                          color="primary"
                          variant="contained"
                          startIcon={<CartIcon />}
                          onClick={() => handleBuy(boost.id)}
                        >
                          Купить
                        </Button>
                      </CardActions>
                    </Card>
                  </Grid>
                );
              })}
            </Grid>

            {boosts.length === 0 && !loading && (
              <Box sx={{ textAlign: 'center', p: 4 }}>
                <Typography variant="body1" color="text.secondary">
                  Бусты не найдены. Попробуйте изменить фильтры.
                </Typography>
              </Box>
            )}

            {pagination.hasMore && (
              <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
                <Button
                  variant="outlined"
                  onClick={handleLoadMore}
                  disabled={loading}
                  startIcon={loading ? <CircularProgress size={20} /> : null}
                >
                  {loading ? 'Загрузка...' : 'Показать ещё'}
                </Button>
              </Box>
            )}
          </>
        )}
      </Paper>
    </Container>

            </Container></Box>
  );
};

export default Shop;