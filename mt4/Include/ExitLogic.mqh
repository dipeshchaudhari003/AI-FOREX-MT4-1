//+------------------------------------------------------------------+
//| ExitLogic.mqh                                                    |
//| GoldPilotAI Enterprise v3.0 - Strategy Layer                     |
//| Trade exit and position management logic                         |
//+------------------------------------------------------------------+
#ifndef __EXITLOGIC_MQH__
#define __EXITLOGIC_MQH__

#include "Config.mqh"
#include "Globals.mqh"
#include "Indicators.mqh"
#include "Utilities.mqh"

//====================================================================
// EXIT LOGIC CONSTANTS
//====================================================================
#define EXIT_TYPE_TP          1
#define EXIT_TYPE_SL          2
#define EXIT_TYPE_BE          3
#define EXIT_TYPE_TRAILING    4
#define EXIT_TYPE_PARTIAL     5
#define EXIT_TYPE_EMERGENCY   6

//====================================================================
// EXIT RESULT STRUCTURE
//====================================================================
struct ExitResult
{
   bool Executed;
   int ExitType;
   double ExitPrice;
   double Profit;
   string ExitReason;
};

//====================================================================
// BREAK EVEN MANAGEMENT
//====================================================================

//--------------------------------------------------------------------
// Move SL to Break-Even for Buy Trades
//--------------------------------------------------------------------
bool MoveToBreakEvenBuy(int ticket, double openPrice)
{
   if(!OrderSelect(ticket, SELECT_BY_POS, MODE_TRADES))
      return false;
   
   if(OrderType() != OP_BUY)
      return false;
   
   // Check if profit is enough to move to BE
   double currentProfit = (Bid - openPrice) / Point;
   
   if(currentProfit < BreakEvenPoints)
      return false;
   
   // Already at or past break-even
   if(OrderStopLoss() >= openPrice - 1*Point)
      return false;
   
   // Move SL to break-even + 1 point (avoid re-trigger)
   bool result = OrderModify(
      ticket,
      OrderOpenPrice(),
      openPrice + 1*Point,
      OrderTakeProfit(),
      0
   );
   
   if(!result)
   {
      Print("BE MODIFY BUY FAILED | Ticket=", ticket, 
            " | Error=", GetLastError());
      return false;
   }
   
   Print("✓ BREAK-EVEN SET (BUY) | Ticket=", ticket, 
         " | Price=", openPrice);
   return true;
}

//--------------------------------------------------------------------
// Move SL to Break-Even for Sell Trades
//--------------------------------------------------------------------
bool MoveToBreakEvenSell(int ticket, double openPrice)
{
   if(!OrderSelect(ticket, SELECT_BY_POS, MODE_TRADES))
      return false;
   
   if(OrderType() != OP_SELL)
      return false;
   
   // Check if profit is enough to move to BE
   double currentProfit = (openPrice - Ask) / Point;
   
   if(currentProfit < BreakEvenPoints)
      return false;
   
   // Already at or past break-even
   if(OrderStopLoss() <= openPrice + 1*Point)
      return false;
   
   // Move SL to break-even - 1 point (avoid re-trigger)
   bool result = OrderModify(
      ticket,
      OrderOpenPrice(),
      openPrice - 1*Point,
      OrderTakeProfit(),
      0
   );
   
   if(!result)
   {
      Print("BE MODIFY SELL FAILED | Ticket=", ticket, 
            " | Error=", GetLastError());
      return false;
   }
   
   Print("✓ BREAK-EVEN SET (SELL) | Ticket=", ticket, 
         " | Price=", openPrice);
   return true;
}

//--------------------------------------------------------------------
// Manage Break-Even for All Trades
//--------------------------------------------------------------------
void ManageBreakEven()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderType() == OP_BUY)
      {
         MoveToBreakEvenBuy(OrderTicket(), OrderOpenPrice());
      }
      else if(OrderType() == OP_SELL)
      {
         MoveToBreakEvenSell(OrderTicket(), OrderOpenPrice());
      }
   }
}

//====================================================================
// TRAILING STOP MANAGEMENT
//====================================================================

//--------------------------------------------------------------------
// Trailing Stop for Buy Trades
//--------------------------------------------------------------------
bool TrailingStopBuy(int ticket, double openPrice, double trailingPoints)
{
   if(!OrderSelect(ticket, SELECT_BY_POS, MODE_TRADES))
      return false;
   
   if(OrderType() != OP_BUY)
      return false;
   
   // Current profit in points
   double currentProfit = (Bid - openPrice) / Point;
   
   // If not enough profit yet, skip
   if(currentProfit < trailingPoints)
      return false;
   
   // Calculate new SL (current price - trailing distance)
   double newSL = Bid - (trailingPoints * Point);
   
   // Only move SL up (never down)
   if(newSL <= OrderStopLoss())
      return false;
   
   bool result = OrderModify(
      ticket,
      OrderOpenPrice(),
      newSL,
      OrderTakeProfit(),
      0
   );
   
   if(!result)
   {
      Print("TRAILING STOP BUY FAILED | Ticket=", ticket, 
            " | Error=", GetLastError());
      return false;
   }
   
   Print("✓ TRAILING STOP UPDATED (BUY) | Ticket=", ticket, 
         " | NewSL=", newSL);
   return true;
}

//--------------------------------------------------------------------
// Trailing Stop for Sell Trades
//--------------------------------------------------------------------
bool TrailingStopSell(int ticket, double openPrice, double trailingPoints)
{
   if(!OrderSelect(ticket, SELECT_BY_POS, MODE_TRADES))
      return false;
   
   if(OrderType() != OP_SELL)
      return false;
   
   // Current profit in points
   double currentProfit = (openPrice - Ask) / Point;
   
   // If not enough profit yet, skip
   if(currentProfit < trailingPoints)
      return false;
   
   // Calculate new SL (current price + trailing distance)
   double newSL = Ask + (trailingPoints * Point);
   
   // Only move SL down (never up)
   if(newSL >= OrderStopLoss())
      return false;
   
   bool result = OrderModify(
      ticket,
      OrderOpenPrice(),
      newSL,
      OrderTakeProfit(),
      0
   );
   
   if(!result)
   {
      Print("TRAILING STOP SELL FAILED | Ticket=", ticket, 
            " | Error=", GetLastError());
      return false;
   }
   
   Print("✓ TRAILING STOP UPDATED (SELL) | Ticket=", ticket, 
         " | NewSL=", newSL);
   return true;
}

//--------------------------------------------------------------------
// Manage Trailing Stop for All Trades
//--------------------------------------------------------------------
void ManageTrailingStop(double trailingPoints)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderType() == OP_BUY)
      {
         TrailingStopBuy(OrderTicket(), OrderOpenPrice(), trailingPoints);
      }
      else if(OrderType() == OP_SELL)
      {
         TrailingStopSell(OrderTicket(), OrderOpenPrice(), trailingPoints);
      }
   }
}

//====================================================================
// DYNAMIC TAKE PROFIT ADJUSTMENT
//====================================================================

//--------------------------------------------------------------------
// Adjust TP based on ATR (when ATR increases, increase TP)
//--------------------------------------------------------------------
bool AdjustTPByATR(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_POS, MODE_TRADES))
      return false;
   
   // Calculate dynamic TP based on ATR
   double atrTP = (ATR * ATRTPFactor) / 100.0;
   
   // Ensure minimum TP
   if(atrTP < DefaultTakeProfit)
      atrTP = DefaultTakeProfit;
   
   // Ensure maximum TP to avoid unrealistic targets
   if(atrTP > ATRTPMaximum)
      atrTP = ATRTPMaximum;
   
   double newTP;
   
   if(OrderType() == OP_BUY)
   {
      newTP = OrderOpenPrice() + (atrTP * Point);
   }
   else if(OrderType() == OP_SELL)
   {
      newTP = OrderOpenPrice() - (atrTP * Point);
   }
   else
      return false;
   
   // Only update if TP is higher (for buy) or lower (for sell)
   bool shouldUpdate = false;
   
   if(OrderType() == OP_BUY && newTP > OrderTakeProfit())
      shouldUpdate = true;
   
   if(OrderType() == OP_SELL && newTP < OrderTakeProfit())
      shouldUpdate = true;
   
   if(!shouldUpdate)
      return false;
   
   bool result = OrderModify(
      ticket,
      OrderOpenPrice(),
      OrderStopLoss(),
      newTP,
      0
   );
   
   if(!result)
   {
      Print("ADJUST TP FAILED | Ticket=", ticket, 
            " | Error=", GetLastError());
      return false;
   }
   
   Print("✓ DYNAMIC TP ADJUSTED | Ticket=", ticket, 
         " | NewTP=", newTP, " | ATR=", ATR);
   return true;
}

//====================================================================
// PARTIAL CLOSE MANAGEMENT
//====================================================================

//--------------------------------------------------------------------
// Close Half Position at Profit Target
//--------------------------------------------------------------------
bool PartialCloseAtTarget(int ticket, double profitTargetPoints)
{
   if(!OrderSelect(ticket, SELECT_BY_POS, MODE_TRADES))
      return false;
   
   double currentProfit = 0;
   
   if(OrderType() == OP_BUY)
   {
      currentProfit = (Bid - OrderOpenPrice()) / Point;
   }
   else if(OrderType() == OP_SELL)
   {
      currentProfit = (OrderOpenPrice() - Ask) / Point;
   }
   else
      return false;
   
   // If profit target not reached yet, skip
   if(currentProfit < profitTargetPoints)
      return false;
   
   // Calculate half lot size
   double halfLot = OrderLots() / 2.0;
   
   // Close half
   int closeTicket = OrderClose(ticket, halfLot, 
                                (OrderType() == OP_BUY ? Bid : Ask), 
                                3, clrOrange);
   
   if(closeTicket < 0)
   {
      Print("PARTIAL CLOSE FAILED | Ticket=", ticket, 
            " | Error=", GetLastError());
      return false;
   }
   
   Print("✓ PARTIAL CLOSE EXECUTED | OriginalTicket=", ticket, 
         " | ClosedTicket=", closeTicket, 
         " | Profit=", currentProfit, "pts");
   return true;
}

//====================================================================
// EMERGENCY CLOSE
//====================================================================

//--------------------------------------------------------------------
// Emergency Close All Trades (System Error or Market Crisis)
//--------------------------------------------------------------------
int EmergencyCloseAll(string reason)
{
   int closedCount = 0;
   
   Print("!!! EMERGENCY CLOSE INITIATED !!! Reason: ", reason);
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      double closePrice = (OrderType() == OP_BUY ? Bid : Ask);
      
      bool closed = OrderClose(OrderTicket(), OrderLots(), closePrice, 5, clrRed);
      
      if(closed)
      {
         closedCount++;
         Print("   Closed: Ticket=", OrderTicket(), 
               " | Price=", closePrice);
      }
      else
      {
         Print("   FAILED to close: Ticket=", OrderTicket(), 
               " | Error=", GetLastError());
      }
   }
   
   Print("Emergency close complete. Closed ", closedCount, " orders.");
   return closedCount;
}

//====================================================================
// MANUAL TRADE MANAGEMENT
//====================================================================

//--------------------------------------------------------------------
// Manage Manual Trades (Orders with MagicNumber = 0)
//--------------------------------------------------------------------
void ManageManualTrades()
{
   if(Period() != PERIOD_M1)
      return;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderMagicNumber() != 0)
         continue;  // Only manual trades (MagicNumber = 0)
      
      int ticket = OrderTicket();
      double openPrice = OrderOpenPrice();
      
      // Apply break-even logic
      if(OrderType() == OP_BUY)
      {
         MoveToBreakEvenBuy(ticket, openPrice);
      }
      else if(OrderType() == OP_SELL)
      {
         MoveToBreakEvenSell(ticket, openPrice);
      }
   }
}

//====================================================================
// CLOSED ORDER TRACKING (For Statistics)
//====================================================================

//--------------------------------------------------------------------
// Check for Recently Closed Orders and Update Statistics
//--------------------------------------------------------------------
void TrackClosedOrders()
{
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      // Only process orders closed after last check
      if(OrderCloseTime() <= lastCloseTime)
         break;
      
      // Update statistics
      if(OrderProfit() >= 0)
      {
         WinningTrades++;
         ConsecutiveLosses = 0;
         
         Print("✅ WINNING TRADE | Profit=", OrderProfit(), 
               " | Ticket=", OrderTicket());
      }
      else
      {
         LosingTrades++;
         ConsecutiveLosses++;
         
         Print("❌ LOSING TRADE | Loss=", OrderProfit(), 
               " | Ticket=", OrderTicket(), 
               " | ConsecutiveLosses=", ConsecutiveLosses);
      }
      
      TodayTrades++;
      lastCloseTime = OrderCloseTime();
   }
}

//====================================================================
// MASTER EXIT MANAGEMENT (Call this from OnTick)
//====================================================================

void ManageExits()
{
   // Update indicator data first
   UpdateIndicators();
   
   // Manage break-even for all trades
   ManageBreakEven();
   
   // Apply trailing stop
   if(UseTrailingStop)
   {
      ManageTrailingStop(TrailingStopPoints);
   }
   
   // Adjust TP dynamically based on ATR
   if(UseDynamicTP)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderMagicNumber() == MagicNumber && 
               OrderSymbol() == Symbol())
            {
               AdjustTPByATR(OrderTicket());
            }
         }
      }
   }
   
   // Manage manual trades
   ManageManualTrades();
   
   // Track closed orders for statistics
   TrackClosedOrders();
}

#endif // __EXITLOGIC_MQH__
