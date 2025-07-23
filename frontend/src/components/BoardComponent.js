import React from 'react';
import { Box, Typography } from '@mui/material';
import CellComponent from "./CellComponent";

const BoardComponent = ({
  board,
  setBoard,
  shipsReady,
  isMyBoard,
  canShoot,
  shoot,
  cellSize = 40
}) => {
  const handleCellClick = (x, y) => {
    if (!shipsReady && isMyBoard) {
      board.addShip(x, y);
    } else if (canShoot && !isMyBoard) {
      shoot(x, y);
    }
    setBoard(board.getCopyBoard());
  };

  // Генерация буквенных координат (A-J)
  const columnLetters = Array.from({ length: board.size }, (_, i) =>
    String.fromCharCode(65 + i)
  );

  // Генерация числовых координат (1-10 или 1-20)
  const rowNumbers = Array.from({ length: board.size }, (_, i) => i + 1);

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column' }}>
      {/* Буквенные координаты (сверху) */}
      <Box sx={{
        display: 'grid',
        gridTemplateColumns: `repeat(${board.size}, 1fr)`,
        textAlign: 'center',
        ml: `${cellSize / 2}px`, // Отступ для цифр слева
        mb: 1
      }}>
        {columnLetters.map(letter => (
          <Typography key={`col-${letter}`} variant="caption">
            {letter}
          </Typography>
        ))}
      </Box>

      <Box sx={{ display: 'flex' }}>
        {/* Числовые координаты (слева) */}
        <Box sx={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          mr: 1,
          width: `${cellSize / 2}px`
        }}>
          {rowNumbers.map(number => (
            <Typography key={`row-${number}`} variant="caption" sx={{ height: cellSize, display: 'flex', alignItems: 'center' }}>
              {number}
            </Typography>
          ))}
        </Box>

        {/* Игровая доска */}
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: `repeat(${board.size}, 1fr)`,
            gap: 0,
            width: 'fit-content',
            border: '2px solid',
            borderColor: canShoot ? 'primary.main' : 'divider',
            borderRadius: 1,
            overflow: 'hidden',
            backgroundColor: 'background.paper'
          }}
        >
          {board.cells.map((row, y) =>
            row.map((cell, x) => (
              <CellComponent
                key={cell.id}
                cell={cell}
                addMark={handleCellClick}
                cellSize={cellSize}
              />
            ))
          )}
        </Box>
      </Box>
    </Box>
  );
};

export default BoardComponent;