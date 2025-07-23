import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button, Grid, Radio, RadioGroup, TextField, Typography, FormControlLabel } from "@mui/material";
import Container from "@mui/material/Container";
import Box from "@mui/material/Box";

const Index = () => {
    const gameId = '6baab3f02a885bd719f';
    const [nickname, setNickname] = useState('');
    const [rank, setRank] = useState('')


    const navigate = useNavigate();

    const startPlay = (event) => {
        event.preventDefault(); // Предотвращаем перезагрузку страницы
        if (nickname && rank) {
            localStorage.setItem("nickname", nickname);
            localStorage.setItem("rank", rank);
            navigate(`/game/size`);
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
                        <Typography variant="h3" gutterBottom>
                            Главная
                        </Typography>
                        <Typography variant="caption" gutterBottom sx={{ display: 'block' }}>
                            ID: {gameId}
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
                            value={rank}
                            onChange={(e) => setRank(e.target.value)}
                        />
                    </Grid>

                    <Grid size="auto">
                        <Button
                            variant="outlined"
                            type="submit"
                            color="action"
                            disabled={!(nickname && rank)}
                            onClick={startPlay}
                        >
                            Подтвердить
                        </Button>
                    </Grid>

                </Grid>



            </Container>
        </Box>



    );
};

export default Index;