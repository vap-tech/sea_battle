import React, {useEffect, useState} from "react";
import {
  Box, Container, Grid, Paper, Typography, Button, IconButton, Divider,
  Slider, Popover, FormControl, InputLabel, Select, MenuItem
} from "@mui/material";
import SettingsIcon from '@mui/icons-material/Settings';
import SentimentSatisfiedAltIcon from '@mui/icons-material/SentimentSatisfiedAlt';
import SentimentVeryDissatisfiedIcon from '@mui/icons-material/SentimentVeryDissatisfied';
import { Snackbar, Dialog, DialogContent, DialogActions, DialogTitle } from "@mui/material";
import ActionsInfo from "../components/ActionsInfo";
import BoardComponent from "../components/BoardComponent";
import { Board } from "../models/Board";
import {useNavigate, useParams} from "react-router-dom";

const getWebSocketUrl = () => {
  // Определяем протокол (ws/wss) на основе текущего протокола страницы
  const protocol = window.location.protocol === 'https:' ? 'wss://' : 'ws://';

  // Берем текущий домен из window.location
  const host = window.location.host;

  // Путь к WebSocket endpoint (можно вынести в конфиг при необходимости)
  const path = '/api/v2/battle-ws';

  return `${protocol}${host}${path}`;
};

const wss = new WebSocket(getWebSocketUrl());

const GamePage = () => {
    const [myBoard, setMyBoard] = useState(new Board(localStorage.board_size === '20' ? 20 : 10));
    const [hisBoard, setHisBoard] = useState(new Board(localStorage.board_size === '20' ? 20 : 10));
    const [cellSize, setCellSize] = useState((localStorage.getItem('board_size') === '10') ? 40:20)
    const [rivalName, setRivalName] = useState('');
    const [rivalRank, setRivalRank] = useState('');
    const [shipsReady, setShipsReady] = useState(false);
    const [canShoot, setCanShoot] = useState(false);
    const [gameResult, setGameResult] = useState(null);           // 'victory' | 'defeat' | null
    const [scoreChange, setScoreChange] = useState(0);    // Изменение очков
    const [confirmSurrender, setConfirmSurrender] = useState(false);
    const [boosts, setBoosts] = useState({
        heal: 1,    // Можно использовать 1 раз за игру
        extra_shot: 3 // Макс 3 использования
    });
    const [missedShots, setMissedShots] = useState([]);
    const [snackbar, setSnackbar] = useState({
        open: false,
        message: '',
        autoHideDuration: 6000
    });
    const [gameId, setGameId] = useState(null);
    const [settingsAnchor, setSettingsAnchor] = useState(null);

    useEffect(() => {
        localStorage.setItem('cellSize', cellSize.toString());
    }, [cellSize]);

    const handleSettingsClick = (event) => {
        setSettingsAnchor(event.currentTarget);
    };

    const handleSettingsClose = () => {
        setSettingsAnchor(null);
    };

    const handleCellSizeChange = (event, newValue) => {
        setCellSize(newValue);
    };

    const settingsOpen = Boolean(settingsAnchor);
    const settingsId = settingsOpen ? 'settings-popover' : undefined;


    // Отправка сдачи
    const sendSurrender = () => {
        wss.send(JSON.stringify({
            type: 'surrender',
            payload: {
                username: localStorage.nickname,
                gameId
            }
        }));
        setConfirmSurrender(false);
    };

    // Обработчик использования буста
    const useBoost = (type) => {
        if (boosts[type] <= 0) return;

        wss.send(JSON.stringify({
            type: 'use_boost',
            payload: {
                username: localStorage.nickname,
                gameId,
                boostType: type,
                missedShots: missedShots
            }
        }));

        setBoosts(prev => ({ ...prev, [type]: prev[type] - 1 }));
    };

    function restart() {
        const newMyBoard = new Board(localStorage.board_size === '20' ? 20 : 10);
        const newHisBoard = new Board(localStorage.board_size === '20' ? 20 : 10);
        newMyBoard.initCells()
        newHisBoard.initCells()
        setMyBoard(newMyBoard);
        setHisBoard(newHisBoard);
    }

    const navigate = useNavigate();

    function shoot(x, y) {
        wss.send(JSON.stringify({
            type:'shoot',
            payload: {
                username: localStorage.nickname,
                gameId: gameId,
                x: x,
                y: y
            }
        }));
        setCanShoot(false); // Блокируем выстрелы до ответа сервера
    }

    wss.onmessage = function(response) {
    const {type, payload} = JSON.parse(response.data);

    switch (type) {
        case 'setGameId': {
            const { gameId } = payload;
            setGameId(gameId);
            break;
        }

        case 'connectToPlay': {
            const {success, rivalName, rivalRank } = payload;
            if (!success) {
                return navigate('/')
            }
            setRivalName(rivalName);
            setRivalRank(rivalRank);
            setShipsReady(true);
            break;
        }

        case 'setCanShoot': {
            setCanShoot(payload.canShoot);
            break;
        }

        case 'afterShoot': {
            const {isMyBoard: targetIsMyBoard, x, y, hit} = payload;

            const board = targetIsMyBoard ? myBoard : hisBoard;
            const setBoard = targetIsMyBoard ? setMyBoard : setHisBoard;

            if (hit) {
                board.addDamage(x, y);
            } else {
                board.addMiss(x, y);
            }
            setBoard(board.getCopyBoard());

            if (!hit && targetIsMyBoard) {
                const misses = missedShots;
                misses.push({ x, y });
                setMissedShots(misses);
            }
            break;
        }

        case 'addShip': {
            const { isMyBoard: targetIsMyBoard, coordinates } = payload;
            const board = myBoard;
            const setBoard = setMyBoard;

            coordinates.forEach(({x, y}) => {
                if (x >= 0 && x < board.size && y >= 0 && y < board.size) {
                    board.addShip(x, y);
                }
            });
            setBoard(board.getCopyBoard());
            break;
        }

        case 'serverMessage': {
            setSnackbar({
                open: true,
                message: payload.text,
                autoHideDuration: payload.duration || 6000
            });
            break;
        }

        case 'gameOver': {
            const { result, scoreChange } = payload;
            setGameResult(result);
            setScoreChange(scoreChange);
            break;
        }

        default:
            console.warn('Unhandled message type:', type, payload);
            break;
    }
}

    const handleCloseSnackbar = (event, reason) => {
        if (reason === 'clickaway') return;
        setSnackbar( prev => ({ ...prev, open: false }) );
    };

    const snackbarAction = (
        <>
            <IconButton
                size="small"
                aria-label="close"
                color="inherit"
                onClick={handleCloseSnackbar}
            >X</IconButton>
        </>
    );

    // Функция рестарта игры
    const restartGame = () => {
        setGameResult(null);
        restart();
        setCanShoot(false);
        wss.send(JSON.stringify({
            type: 'connect',
            payload: {
                username: localStorage.nickname,
                board_size: localStorage.board_size,
                rank: localStorage.rank
            }
        }
        ))
    };

    const onTimeEnd = () => {

        wss.send(JSON.stringify({
            type: 'timeout',
            payload: {
                username: localStorage.nickname,
                gameId: gameId }}))
    };

    useEffect(() => {

        wss.send(JSON.stringify({
            type: 'connect',
            payload: {
                username: localStorage.nickname,
                board_size: localStorage.board_size,
                rank: localStorage.rank
            }
        }
        ))

        restart()

    }, [])

    return (
        <Box
            sx={(theme) => ({
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

                <Box sx={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    width: '100%',
                    alignItems: 'center',
                    mb: 2
                }}>

            <Typography variant="h4" gutterBottom>
                        Морской бой
            </Typography>

                {/* Кнопка настроек */}
                <IconButton
                    aria-label="settings"
                    onClick={handleSettingsClick}
                    color="primary"
                    size="large"
                    >
                    <SettingsIcon fontSize="inherit" />
                </IconButton>

                {/* Поповер с настройками */}
                    <Popover
                        id={settingsId}
                        open={settingsOpen}
                        anchorEl={settingsAnchor}
                        onClose={handleSettingsClose}
                        anchorOrigin={{
                            vertical: 'bottom',
                            horizontal: 'right',
                        }}
                        transformOrigin={{
                            vertical: 'top',
                            horizontal: 'right',
                        }}
                    >
                        <Box sx={{ p: 3, width: 300 }}>
                            <Typography variant="h6" gutterBottom>
                                Настройки игры
                            </Typography>

                            <Typography gutterBottom>
                                Размер ячеек: {cellSize}px
                            </Typography>
                            <Slider
                                value={cellSize}
                                onChange={handleCellSizeChange}
                                min={20}
                                max={60}
                                step={5}
                                marks={[
                                    { value: 20, label: '20px' },
                                    { value: 40, label: '40px' },
                                    { value: 60, label: '60px' },
                                ]}
                                valueLabelDisplay="auto"
                            />
                        </Box>
                    </Popover>
                </Box>

            <Grid container justifyContent="space-between" spacing={4} sx={{ width: '100%' }}>

                {/* Левый блок (игрок) */}
                <Grid item xs={12} md={5}>
                        <Paper elevation={3} sx={{ p: 2 }}>
                            <Typography variant="subtitle1">Имя: {localStorage.nickname}</Typography>
                            <Typography variant="subtitle1">Ранг: {localStorage.rank}</Typography>
                            <Divider sx={{ my: 1 }} />
                            <BoardComponent
                                boardSize={(localStorage.getItem('board_size') === '10') ? 10:20}
                                board={myBoard}
                                isMyBoard
                                shipsReady={shipsReady}
                                setBoard={setMyBoard}
                                canShoot={false}
                                cellSize={cellSize}
                            />
                        </Paper>
                    </Grid>



                {/* Правый блок (противник) */}
                <Grid item xs={12} md={5}>
                        <Paper elevation={3} sx={{ p: 2 }}>
                            <Typography variant="subtitle1">
                                Имя: {rivalName || 'Неизвестно'}
                            </Typography>
                            <Typography variant="subtitle1">
                                Ранг: {rivalRank || 'Неизвестен'}
                            </Typography>
                            <Divider sx={{ my: 1 }} />
                            <BoardComponent
                                boardSize={(localStorage.getItem('board_size') === '10') ? 10:20}
                                board={hisBoard}
                                setBoard={setHisBoard}
                                canShoot={canShoot}
                                shipsReady={shipsReady}
                                shoot={shoot}
                                cellSize={cellSize}
                            />
                        </Paper>
                    </Grid>
            </Grid>
            </Container>


            {/* Кнопки управления */}
            <Box sx={{ position: 'fixed', bottom: 16, right: 16, display: 'flex', gap: 2 }}>


                    <ActionsInfo canShoot={canShoot} shipsReady={shipsReady} onTimeEnd={onTimeEnd}/>


                {/* Буст восстановления */}
                <Button
                    variant="contained"
                    color="secondary"
                    disabled={boosts.heal <= 0 || !canShoot}
                    onClick={() => useBoost('heal')}
                    startIcon={<span style={{ fontSize: '1.2em' }}>🛠️</span>}
                    sx={{ minWidth: 220 }}
                >
                    Ремонт ({boosts.heal})
                </Button>

                {/* Буст допвыстрела */}
                <Button
                    variant="contained"
                    color="secondary"
                    disabled={boosts.extra_shot <= 0 || !canShoot}
                    onClick={() => useBoost('extra_shot')}
                    startIcon={<span style={{ fontSize: '1.2em' }}>🎯</span>}
                    sx={{ minWidth: 220 }}
                >
                    Допвыстрел ({boosts.extra_shot})
                </Button>

                {/* Кнопка сдачи */}
                <Button
                    variant="outlined"
                    color="error"
                    onClick={() => setConfirmSurrender(true)}
                    startIcon={<span style={{ fontSize: '1.2em' }}>🏳️</span>}
                >
                    Сдаться
                </Button>

                {/* Диалог подтверждения сдачи */}
                <Dialog open={confirmSurrender}>
                    <DialogTitle>Подтверждение</DialogTitle>
                    <DialogContent>
                        Вы уверены, что хотите сдаться?
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={() => setConfirmSurrender(false)}>Отмена</Button>
                        <Button
                            color="error"
                            variant="contained"
                            onClick={sendSurrender}
                        >
                            Сдаться
                        </Button>
                    </DialogActions>
                </Dialog>
            </Box>


            {/* Диалог завершения игры */}
            <Dialog
                open={Boolean(gameResult)}
                maxWidth="xs"
                fullWidth
            >
                <DialogTitle align="center">
                        {
                            gameResult === 'victory'
                            ? <SentimentSatisfiedAltIcon color='success'/>
                            : <SentimentVeryDissatisfiedIcon color='error'/>
                        }
                </DialogTitle>

                <DialogContent>
                    <Typography
                        variant="h4"
                        align="center"
                        color={gameResult === 'victory' ? 'success.main' : 'error.main'}
                        gutterBottom
                    >
                        {gameResult === 'victory' ? 'Победа!' : 'Поражение'}
                    </Typography>

                    <Typography
                        variant="h6"
                        align="center"
                    >
                        {scoreChange > 0 ? `+${scoreChange}` : scoreChange} очков
                    </Typography>
                </DialogContent>

                <DialogActions sx={{ justifyContent: 'center', pb: 3 }}>
                    <Button onClick={() => {setGameResult(null); setGameId(null)}}>Отмена</Button>
                    <Button
                        variant="contained"
                        color="primary"
                        size="large"
                        onClick={restartGame}
                    >
                        В бой!
                    </Button>
                </DialogActions>
            </Dialog>

            <Snackbar
                open={snackbar.open}
                autoHideDuration={snackbar.autoHideDuration}
                onClose={handleCloseSnackbar}
                message={snackbar.message}
                action={snackbarAction}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'left' }}
                sx={{
                    '& .MuiSnackbarContent-root': {
                        flexWrap: 'nowrap' // Чтобы текст не переносился
                    }
                }}
            />

        </Box>
    );
}

export default GamePage;