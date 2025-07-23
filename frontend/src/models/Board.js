export class Board {
  constructor(size = 10) {
    this.size = size;
    this.cells = [];
    this.initCells();
  }

  initCells() {
    this.cells = Array(this.size).fill().map((_, y) =>
      Array(this.size).fill().map((_, x) => ({
        x,
        y,
        mark: null,
        id: `${x}-${y}`
      }))
    );
  }

  getCells(x, y) {
    if (y >= 0 && y < this.size && x >= 0 && x < this.size) {
      return this.cells[y][x];
    }
    return null;
  }

  addShip(x, y) {
    const cell = this.getCells(x, y);
    if (cell) {
      cell.mark = {
        name: 'ship',
        color: 'primary',
        logo: 'S'
      };
    }
  }

  addDamage(x, y) {
    const cell = this.getCells(x, y);
    if (cell) {
      cell.mark = {
        name: 'hit',
        color: 'error',
        logo: '💥'
      };
    }
  }

  addMiss(x, y) {
    const cell = this.getCells(x, y);
    if (cell) {
      cell.mark = {
        name: 'miss',
        color: 'secondary',
        logo: '·'
      };
    }
  }

  getCopyBoard() {
    const newBoard = new Board(this.size);
    newBoard.cells = JSON.parse(JSON.stringify(this.cells));
    return newBoard;
  }
}