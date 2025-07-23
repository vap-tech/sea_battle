### **WebSocket API Contract v1.0**

#### **Общие принципы**
1. Все сообщения передаются в формате JSON
2. Сервер и клиент отправляют сообщения с полями:
```json
{
    "type": "string",
    "payload": "any"
}
```
##### Где:
- **type** - определяет тип передаваемого события
- **payload** - содержит данные события

---

### **1. События от клиента → сервер**

| Тип (`type`) | Данные события (`payload`)                                     | Назначение                |
|--------------|----------------------------------------------------------------|---------------------------|
| `connect`    | `{ username: string, gameId: string }`                         | Первое подключение к игре |
| `shoot`      | `{ username: string, gameId: string, x: number, y: number }`   | Выстрел по координатам    |
| `restart`    | `{ username: string, gameId: string }`                         | Запрос новой игры         |
| `use_boost`  | `{ username: string, gameId: string, boostType: 'heal'}`       | Буст восстановления       |
| `use_boost`  | `{ username: string, gameId: string, boostType: 'extra_shot'}` | Буст двойного выстрела    |
| `surrender`  | `{ username: string, gameId: string }`                         | Сдаться                   |
| `timeout`    | `{ username: string, gameId: string }`                         | Таймаут                   |

### **1.1. Примеры сообщений**

#### 1.1.1 Подключение к игре
```
{
  "type": "connect",
  "payload": {
    "username": "Player1",
    "gameId": "jdkfnbdfkl564klk5nmgf"
  }
}
```
#### 1.1.2 Выстрел
```
{
  "type": "shoot",
  "payload": {
    "username": "Player1",
    "gameId": "ghfghj5htht12345",
    "x": 3,
    "y": 5
  }
}
```
#### 1.1.3 Запрос новой игры
```
{
  "type": "restart",
  "payload": {
    "username": "Player1",
    "gameId": "ghfghj5htht12345"
  }
}
```
#### 1.1.4 Использование буста
##### Восстановление корабля
```
{
  "type": "use_boost",
  "payload": {
    "username": "Alex",
    "gameId": "hmg243532jn45kj235n",
    "boostType": "heal"
  }
}
```
##### Двойной выстрел
```
{
  "type": "use_boost",
  "payload": {
    "username": "Alex",
    "gameId": "hmg243532jn45kj235n",
    "boostType": "extra_shot" 
  }
}
```
#### 1.1.5 Сдача
```
{
  "type": "surrender",
  "payload": {
    "username": "Player1",
    "gameId": "ghfghj5htht12345"
  }
}
```

---

### **2. События от сервера → клиент**
| Тип (`type`)    | `payload`                                                    | Назначение                    |
|-----------------|--------------------------------------------------------------|-------------------------------|
| `connectToPlay` | `{ success: boolean, rivalName?: string }`                   | Подтверждение подключения     |
| `setGameId`     | `{ gameId: string }`                                         | Установка id текущей игры     |
| `setCanShoot`   | `{ canShoot: boolean }`                                      | Разрешение/запрет хода        |
| `afterShoot`    | `{ isMyBoard: boolean, x: number, y: number, hit: boolean }` | Отрисовка результата выстрела |
| `addShip`       | `{ board: string, coordinates: {x,y}[], name: string }`      | Добавление корабля            |
| `gameOver`      | `{ result: "victory"\|"defeat", scoreChange: number }`       | Конец игры                    |
| `serverMessage` | `{ text: string, duration?: number }`                        | Системное уведомление         |

### **2.1. Примеры сообщений**

#### 2.1.1 Подключение к игре
```
{
  "type": "connectToPlay",
  "payload": {
    "success": true,
    "rivalName": "Player2"
  }
}
```
#### 2.1.2 Установка gameId
```
{
  "type": "setGameId",
  "payload": {
    "gameId": "dgfhgrf543634563etghdfhdf"
  }
}
```
#### 2.1.3 Разрешение хода
```
{
  "type": "setCanShoot",
  "payload": {
    "canShoot": true
  }
}
```
#### 2.1.4 Запрет хода
```
{
  "type": "setCanShoot",
  "payload": {
    "canShoot": false
  }
}
```
#### 2.1.5 Отрисовка выстрела по моей доске
```
{
  "type": "afterShoot",
  "payload": {
    "isMyBoard": true
    "x": 3,
    "y": 5,
    "hit": true // true - попал, false не попал
  }
}
```
#### 2.1.6 Отрисовка выстрела по доске оппонента
```
{
  "type": "afterShoot",
  "payload": {
    "isMyBoard": false
    "x": 3,
    "y": 5,
    "hit": false
  }
}
```
#### 2.1.7 Отрисовка корабля на моей доске
```
{
  "type": "addShip",
  "payload": {
    "isMyBoard": false
    "x": 3,
    "y": 5,
    "hit": false
  }
}
```


#### Системное сообщение
```json
{
  "type": "message",
  "payload": {
    "text": "Противник подключился к игре",
    "duration": 3000
  }
}
```