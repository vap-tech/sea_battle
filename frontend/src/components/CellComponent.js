import React from 'react';
import { Box, Tooltip } from '@mui/material';

const CellComponent = ({ cell, addMark, cellSize = 40 }) => {
  const getCellStyles = () => {
    const baseStyles = {
      width: cellSize,
      height: cellSize,
      minWidth: cellSize,
      minHeight: cellSize,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      cursor: 'pointer',
      border: '1px solid rgba(0, 0, 0, 0.1)',
      '&:hover': {
        backgroundColor: 'action.hover',
      }
    };

    if (cell?.mark) {
      if (cell.mark.name === 'miss') {
        return {
          ...baseStyles,
          color: 'text.secondary'
        };
      } else if (cell.mark.name === 'ship') {
        return {
          ...baseStyles,
          backgroundColor: 'primary.light',
          color: 'primary.contrastText'
        };
      } else if (cell.mark.name === 'hit') {
        return {
          ...baseStyles,
          backgroundColor: 'error.main',
          color: 'error.contrastText'
        };
      }
      else if (cell.mark.color) {
        return {
          ...baseStyles,
          backgroundColor: cell.mark.color,
          color: 'common.white'
        };
      }
    }

    return baseStyles;
  };

  const renderCellContent = () => {
    if (cell?.mark) {
      if (cell.mark.name === 'miss') {
        return '·';
      } else if (cell.mark.logo) {
        return cell.mark.logo;
      }
    }
    return null;
  };

  return (
    <Tooltip title={`${String.fromCharCode(65 + cell.x)}${cell.y + 1}`} arrow>
      <Box
        sx={getCellStyles()}
        onClick={() => addMark(cell.x, cell.y)}
      >
        {renderCellContent()}
      </Box>
    </Tooltip>
  );
};

export default CellComponent;