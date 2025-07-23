import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button, Grid, Radio, RadioGroup, TextField, Typography, FormControlLabel } from "@mui/material";
import Container from "@mui/material/Container";
import Box from "@mui/material/Box";

const GameSize = ({ user }) => {

    console.log(user);

    const gameId = '6baab3f02e7c377c8c5e00a885bd719f';
    const [nickname, setNickname] = useState(user.name);
    const [rank, setRank] = useState(user.rank)
    const [boardSize, setBoardSize] = useState(10);

    const navigate = useNavigate();

    const startPlay = (event) => {
        event.preventDefault(); // Предотвращаем перезагрузку страницы
        if (nickname && rank) {
            localStorage.setItem("nickname", nickname);
            localStorage.setItem("rank", rank);
            localStorage.setItem("board_size", boardSize.toString()); // Размер поля
            navigate(`/game/play`);
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

                <Grid container direction="column" alignItems="center" spacing={2}>

                    <Grid size="auto">
                        <Typography variant="h5" component="h2" gutterBottom>
                            Параметры игры
                        </Typography>
                    </Grid>

                    <Grid size="auto">
                        <TextField
                            variant="standard"
                            label="Ваше имя"
                            fullWidth
                            required
                            name="nickname"
                            id="nickname"
                            disabled={nickname !== null}
                            value={nickname}
                            onChange={(e) => setNickname(e.target.value)}
                        />
                    </Grid>

                    <Grid size="auto">
                        <TextField
                            variant="standard"
                            label="Ранг"
                            fullWidth
                            required
                            name="rank"
                            id="rank"
                            disabled={rank !== null}
                            value={rank}
                            onChange={(e) => setRank(e.target.value)}
                        />
                    </Grid>

                    <Grid size="auto">
                        <Typography variant="subtitle1" gutterBottom>
                            Размер поля
                        </Typography>
                        <RadioGroup
                            row
                            aria-label="boardSize"
                            name="boardSize"
                            value={boardSize.toString()}
                            onChange={(e) => setBoardSize(parseInt(e.target.value))}
                        >
                            <FormControlLabel value="10" control={<Radio />} label="10x10" />
                            <FormControlLabel value="20" control={<Radio />} label="20x20" />
                        </RadioGroup>
                    </Grid>

                    <Grid size="auto">
                        <Button
                            variant="outlined"
                            type="submit"
                            color="action"
                            disabled={!(nickname && rank)}
                            onClick={startPlay}
                        >
                            Играть
                        </Button>
                    </Grid>

                </Grid>



            </Container>
        </Box>



    );
};

export default GameSize;