import React from 'react';
import { CircularProgress, Typography } from '@mui/material';
import Box from '@mui/material/Box';
import CircularWithValueLabel from "./CircularProgressWithLabel";

const ActionsInfo = ({ shipsReady = false, canShoot = false, onTimeEnd }) => {

    if (!shipsReady) {
        return (
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>


                        <CircularProgress color="inherit" />
                        <Typography variant="body1">
                            Ожидаем соперника
                        </Typography>


            </Box>
        );
    }

    if (canShoot) {
        return (
            <Box sx={{display: 'flex', alignItems: 'center', gap: 2}}>

                <CircularWithValueLabel onTimeEnd={onTimeEnd}/>
                <Typography variant="body1">
                    Стреляй!
                </Typography>


            </Box>
        );
    }

    return (
        <Box sx={{display: 'flex', alignItems: 'center', gap: 2}}>
        <Typography variant="body1">
            Выстрел соперника...
        </Typography>
        </Box>
    );
};

export default ActionsInfo;





