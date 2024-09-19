//+------------------------------------------------------------------+
//|                                             Martingale Grid MT 4 |
//|                                    Copyright 2024, Yohan Naftali |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Yohan Naftali"
#property link      "https://github.com/yohannaftali"
#property version   "1.00"
#property strict

enum orderDirection
{
  orderDirection1 = 1, // Buy Only
  orderDirection2 = 2, // Sell Only
  orderDirection3 = 3  // Buy And Sell
};

//+------------------------------------------------------------------+
//| Input                                                            |
//+------------------------------------------------------------------+
input orderDirection ORDER_DIRECTION = 3;    // Order Direction
input ENUM_TIMEFRAMES TIMEFRAME = PERIOD_M1; // Timeframe Period
input int MAX_TICK_VOLUME = 10;              // Maximum Tick Volume to Open Trade
input double BASE_VOLUME = 0.01;             // Base Volume
input double MULTIPLIER = 1.06;              // Volume Multiplier
input int TP_BY_POINT = 100;                 // Take Profit by Point (Point), 0 to disable
input double TP_BY_PERCENTAGE = 0;           // Take Profit by Percentage (%), 0 to disable
input int MAGIC_NUMBER = 1;                  // EA Magic Number
input string COMMENT = "GM_M1";              // EA Comment
input int SLIPPAGE_OPEN = 2;                 // Slippage Open (Point)
input int SLIPPAGE_CLOSE = 10;               // Slippage Close (Point)
input double MODIFY_STEP_TP = 10;            // Step Modify Take Profit by Point

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
int digitPrice;
int digitVolume;
double symbolPoint;
double baseVolume;
double maxVolume;
double minVolume;
double tpByPercentage = 0;
double tpByPoint = 0;
double marginPrice;
string SystemTag = "GM_" + IntegerToString(MAGIC_NUMBER);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  ObjectsDeleteAll(ChartID(), SystemTag);
  if(TP_BY_POINT > 0) {
    createButton(SystemTag + "_UP_BUTTON", clrGreen, clrGreen, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 40, "Modify TP by Point Up +" + DoubleToString(MODIFY_STEP_TP, 2) );
    createButton(SystemTag + "_DW_BUTTON", clrOrangeRed, clrOrangeRed, clrWhite, 500, 40, CORNER_LEFT_UPPER, 20, 100, "Modify TP by Point Down -" + DoubleToString(MODIFY_STEP_TP, 2));
  }
  createButton(SystemTag + "_CL_BUTTON_BUY", clrRed, clrRed, clrWhite, 500, 40, CORNER_RIGHT_UPPER, 520, 100, "Close All Buy Position !!!");
  createButton(SystemTag + "_CL_BUTTON_SELL", clrRed, clrRed, clrWhite, 500, 40, CORNER_RIGHT_UPPER, 520, 160, "Close All Sell Position !!!");

  double balance = AccountBalance();
  double equity = AccountEquity();
  double margin = AccountMargin();
  double freeMargin = AccountFreeMargin();
  Print("# Account Info");
  Print("- Balance: " + DoubleToString(balance, 2));
  Print("- Equity: " + DoubleToString(equity, 2));
  Print("- Margin: " + DoubleToString(margin, 2));
  Print("- Free Margin: " + DoubleToString(freeMargin, 2));

  symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  digitPrice = (int) MarketInfo(_Symbol, MODE_DIGITS);
  tpByPercentage = TP_BY_PERCENTAGE;
  tpByPoint = TP_BY_POINT;
  marginPrice = tpByPoint * symbolPoint;
  double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
  minVolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
  maxVolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
  digitVolume = getDigit(step);
  baseVolume = BASE_VOLUME < minVolume ? minVolume : BASE_VOLUME;
  baseVolume = baseVolume > maxVolume ? maxVolume : baseVolume;
  baseVolume = NormalizeDouble(baseVolume, digitVolume);
  Print("symbolPoint: " + DoubleToString(symbolPoint, _Digits));
  Print("Digit Price: " + IntegerToString(digitPrice, _Digits));
  Print("Digit Volume: " + IntegerToString(digitVolume, _Digits));
  Print("Margin Price: " + DoubleToString(marginPrice, _Digits));

  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void modifyTpByPoint(double change)
{
  tpByPoint = tpByPoint + change;
  if(tpByPoint < 0) {
    tpByPoint = 0;
  }
  marginPrice = tpByPoint * symbolPoint;

  if(tpByPoint == 0) return;

  if(ORDER_DIRECTION == 1 || ORDER_DIRECTION == 3) {
    modifyPosition(OP_BUY);
  }
  if(ORDER_DIRECTION == 2 || ORDER_DIRECTION == 3) {
    modifyPosition(OP_SELL);
  }
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  deleteObject();
  Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  handleTakeProfitPercentage();
  if(!isNewBar()) return;
  setupTrade();
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
  if(id == CHARTEVENT_OBJECT_CLICK) {
    if(sparam == SystemTag + "_UP_BUTTON") {
      // Modify Takeprofit Up
      int confirmation = MessageBox("Are you sure to modify take profit by point up?", "TP +" + DoubleToString(MODIFY_STEP_TP, 2), MB_OKCANCEL);
      if(confirmation == IDOK) {
        modifyTpByPoint(MODIFY_STEP_TP);
        MessageBox("All position modified", "Modify done", MB_OK);
      }
    }

    else if(sparam == SystemTag + "_DW_BUTTON") {
      // Modify Takeprofit Down
      int confirmation = MessageBox("Are you sure to modify take profit by point down?", "TP -" + DoubleToString(MODIFY_STEP_TP, 2), MB_OKCANCEL);
      if(confirmation == IDOK) {
        modifyTpByPoint(-MODIFY_STEP_TP);
        MessageBox("All position modified", "Modify done", MB_OK);
      }
    }

    else if(sparam == SystemTag + "_CL_BUTTON_BUY") {
      // Close all position
      int confirmation = MessageBox("Are you sure to close all buy position?", "Close Buy", MB_OKCANCEL);
      if(confirmation == IDOK) {
        closeAllPosition(OP_BUY);
        MessageBox("All buy position Cleared", "Close Position Done", MB_OK);
      }
    }

    else if(sparam == SystemTag + "_CL_BUTTON_SELL") {
      // Close all position
      int confirmation = MessageBox("Are you sure to close all sell position?", "Close Sell", MB_OKCANCEL);
      if(confirmation == IDOK) {
        closeAllPosition(OP_SELL);
        MessageBox("All sell position Cleared", "Close Position Done", MB_OK);
      }
    }
  }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void handleTakeProfitPercentage()
{
  if(tpByPercentage == 0) return;
  double balance = AccountInfoDouble(ACCOUNT_BALANCE);
  double target = balance * tpByPercentage/100;
  if(ORDER_DIRECTION == 1 || ORDER_DIRECTION == 3) {
    double profit = sumProfit(OP_BUY);
    if(profit >= target)
      closeAllPosition(OP_BUY);
  }

  if(ORDER_DIRECTION == 2 || ORDER_DIRECTION == 3) {
    double profit =sumProfit(OP_SELL);
    if(profit >= target)
      closeAllPosition(OP_SELL);
  }
  return;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setupTrade()
{
  MqlRates rates[];
  ArraySetAsSeries(rates, true);
  CopyRates(_Symbol, TIMEFRAME, 0, 1, rates);
  long tickVolume = rates[0].tick_volume;
  if(tickVolume > MAX_TICK_VOLUME) return;

  MqlTick tick;
  SymbolInfoTick(_Symbol, tick);
  double askPrice = tick.ask;
  askPrice = NormalizeDouble(askPrice, _Digits);
  double bidPrice = tick.bid;
  bidPrice = NormalizeDouble(bidPrice, _Digits);

  setupBuy(askPrice);
  setupSell(bidPrice);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setupBuy(double price)
{
  if(ORDER_DIRECTION == 2) return;
  int grid = countOrder(OP_BUY);
  double volume = calculateVolume(grid);
  if(grid == 0) {
    sendOrder(OP_BUY, volume, price);
    return;
  }
  if(!(price < lowestPendingBuyPrice())) return;
  sendOrder(OP_BUY, volume, price);
  return;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setupSell(double price)
{
  if(ORDER_DIRECTION == 1) return;
  int grid = countOrder(OP_SELL);
  double volume = calculateVolume(grid);
  if(grid == 0) {
    sendOrder(OP_SELL, volume, price);
    return;
  }
  if(!(price > highestPendingSellPrice())) return;
  sendOrder(OP_SELL, volume, price);
  return;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculateVolume(int grid)
{
  if(grid == 0) return baseVolume;
  double volume = baseVolume * MathPow(MULTIPLIER, grid);
  volume = volume < minVolume ? minVolume : volume;
  volume = volume > maxVolume ? maxVolume : volume;
  volume = NormalizeDouble(volume, digitVolume);
  return volume;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double highestPendingSellPrice()
{
  double value = DBL_MIN;
  for(int i = (OrdersTotal() - 1); i >= 0; i--) {
    if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
    if(OrderSymbol() != _Symbol) continue;
    if(OrderMagicNumber() != MAGIC_NUMBER) continue;
    if(OrderType() != OP_SELL) continue;
    value = MathMax(OrderOpenPrice(), value);
  }
  return value;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double lowestPendingBuyPrice()
{
  double value = DBL_MAX;
  for(int i = (OrdersTotal() - 1); i >= 0; i--) {
    if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
    if(OrderSymbol() != _Symbol) continue;
    if(OrderMagicNumber() != MAGIC_NUMBER) continue;
    if(OrderType() != OP_BUY) continue;
    value = MathMin(OrderOpenPrice(), value);
  }
  return value;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void sendOrder(ENUM_ORDER_TYPE orderType, double volume, double price)
{
  int ticket = OrderSend(_Symbol, orderType, volume, price, SLIPPAGE_OPEN, 0, 0, COMMENT, MAGIC_NUMBER, 0, clrNONE);
  if(!ticket) {
    Print("Error: Failed to send order");
  }
  if(tpByPoint == 0) return;
  modifyPosition(orderType);
  return;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void modifyPosition(ENUM_ORDER_TYPE orderType)
{
  double avg = averagePositionPrice(orderType);
  if(avg == 0) return;
  double tp = orderType == OP_BUY ? avg + marginPrice : avg - marginPrice;
  tp = NormalizeDouble(tp, _Digits);

  Print("Order Type: " + EnumToString(orderType));
  Print("Average Price: " + DoubleToString(avg, _Digits));
  Print("Margin: " + DoubleToString(marginPrice, _Digits));
  Print("New TP: " + DoubleToString(tp, _Digits));
  for(int i = (OrdersTotal() - 1); i >= 0; i--) {
    if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
    if(OrderSymbol() != _Symbol) continue;
    if(OrderMagicNumber() != MAGIC_NUMBER) continue;
    if(OrderType() != orderType) continue;
    if(OrderTakeProfit() == tp) continue;
    int ticket = OrderTicket();
    double openPrice = OrderOpenPrice();
    double sl = OrderStopLoss();
    bool res = OrderModify(ticket, openPrice, sl, tp, 0, clrNONE);
    Print("Modify order ticket no #" + IntegerToString(ticket) + " new TP: " + DoubleToString(tp, _Digits));
    if(!res) {
      Print("Error modify order ticket no #" + IntegerToString(ticket));
    }
  }
  return;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double averagePositionPrice(ENUM_ORDER_TYPE orderType)
{
  double sumVolume = 0;
  double sumOrder = 0;
  for(int i = (OrdersTotal() - 1); i >= 0; i--) {
    if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
    if(OrderSymbol() != _Symbol) continue;
    if(OrderMagicNumber() != MAGIC_NUMBER) continue;
    if(OrderType() != orderType) continue;
    double volume = OrderLots();
    double openPrice = OrderOpenPrice();
    double order = openPrice * volume;
    sumVolume += volume;
    sumOrder += order;
  }
  double averagePrice = sumVolume > 0 ? sumOrder / sumVolume : 0;
  averagePrice = NormalizeDouble(averagePrice, _Digits);
  return averagePrice;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeAllPosition(ENUM_ORDER_TYPE orderType)
{
  double price = orderType == OP_BUY
                 ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                 : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  for(int i = (OrdersTotal() - 1); i >= 0; i--) {
    if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
    if(OrderSymbol() != _Symbol) continue;
    if(OrderMagicNumber() != MAGIC_NUMBER) continue;
    if(OrderType() != orderType) continue;
    int ticket = OrderTicket();
    double volume = OrderLots();
    bool res = OrderClose(ticket, volume, price, SLIPPAGE_CLOSE, clrNONE);
    if(!res) {
      Print("Error close order ticket no #" + IntegerToString(ticket));
    }
  }
  return;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double sumProfit(ENUM_ORDER_TYPE orderType)
{
  double sumProfit = 0;
  for(int i = (OrdersTotal() - 1); i >= 0; i--) {
    if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
    if(OrderSymbol() != _Symbol) continue;
    if(OrderMagicNumber() != MAGIC_NUMBER) continue;
    if(OrderType() != orderType) continue;
    sumProfit += OrderProfit() + OrderSwap() + OrderCommission();
  }
  return sumProfit;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int countOrder(int orderType)
{
  int count = 0;
  for(int i = (OrdersTotal() - 1); i >= 0; i--) {
    if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
    if(OrderSymbol() != _Symbol) continue;
    if(OrderMagicNumber() != MAGIC_NUMBER)  continue;
    if(OrderType() != orderType) continue;
    count++;
  }
  return count;
}

//+------------------------------------------------------------------+
//| Get Digit of given number                                        |
//+------------------------------------------------------------------+
int getDigit(double number)
{
  int d = 0;
  double p = 1;
  while(MathRound(number * p) / p != number) {
    p = MathPow(10, ++d);
  }
  return d;
}

//+------------------------------------------------------------------+
//| Return whether current tick is a new bar                         |
//+------------------------------------------------------------------+
bool isNewBar()
{
  static datetime lastBar;
  return lastBar != (lastBar = iTime(Symbol(), PERIOD_M1, 0));
}

//+------------------------------------------------------------------+
//| Delete object all or by name                                     |
//+------------------------------------------------------------------+
void deleteObject(string objectName = "")
{
  for(int i = (ObjectsTotal() - 1); i >= 0; i--) {
    if(StringFind(ObjectName(i), WindowExpertName()) != -1) {
      if(objectName == "") {
        ObjectDelete(ObjectName(i));
        continue;
      } else if(StringFind(ObjectName(i), objectName) != -1) {
        ObjectDelete(ObjectName(i));
      }
    }
  }
}

//+------------------------------------------------------------------+
//| Create Button Wrapper                                            |
//+------------------------------------------------------------------+
void createButton(string buttonName, color bgClr, color borderClr, color textClr, int width, int height, int corner, int x, int y, string label)
{
  ObjectCreate(0, buttonName, OBJ_BUTTON, 0, 0, 0);
  ObjectSetInteger(0, buttonName, OBJPROP_BGCOLOR, bgClr);
  ObjectSetInteger(0, buttonName, OBJPROP_BORDER_COLOR, borderClr);
  ObjectSetInteger(0, buttonName, OBJPROP_COLOR, textClr);
  ObjectSetInteger(0, buttonName, OBJPROP_YSIZE, height);
  ObjectSetInteger(0, buttonName, OBJPROP_XSIZE, width);
  ObjectSetInteger(0, buttonName, OBJPROP_CORNER, corner);
  ObjectSetInteger(0, buttonName, OBJPROP_XDISTANCE, x);
  ObjectSetInteger(0, buttonName, OBJPROP_YDISTANCE, y);
  ObjectSetString(0, buttonName, OBJPROP_TEXT, label);
  ObjectSetInteger(0, buttonName, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
