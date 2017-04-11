classdef TradingRobot < AutoTrader
  properties
    AssetMgr
    AlgoParams
    Triggers
    TriggersData
    PerfMeasure
  end

  methods
    function self = TradingRobot
      % Initializing the assets manager with the two ISINs.
      self.AssetMgr = AssetManager;
      self.AssetMgr.Init({'DBK_EUR', 'CBK_EUR'});

      % This struct contains basic parameters of the algorithm.
      % max_trading_volume :    maximum amount of shares to hold at any given tick.
      % lookback :              number of past ticks to consider for computations.
      % trigger_params :        several parameters used mainly for triggers.1
      %   dtsmax :              number of ticks we wait before selling stock.
      %   dtbmax :              number of ticks we wait before buying stock.
      %   dthmax :              maximum ticks we hold to the stock.
      %   dssmax :              maximum change of the stock's price before selling.
      %   dsbmax :              change in price before buying.
      self.AlgoParams = struct('max_trading_volume', struct, 'lookback', 100, 'trigger_params', struct('dtsmax', 30, 'dtbmax', 30, 'dthmax', 10, 'dssmax', 0.0, 'dsbmax', 0.0));

      self.AlgoParams.max_trading_volume.DBK_EUR = 10;
      self.AlgoParams.max_trading_volume.CBK_EUR = 10;

      % Here triggers are stored as functions that only take "self" as an argument.
      % TriggersData contains information specific to each function, for bookkeeping.
      % TriggersData.Global is reserved for information concerning more than one trigger.
      self.Triggers = cell(0);
      self.TriggersData = struct;
      self.TriggersData.Global = struct;

      % Placeholder struct to store performance-related stuff.
      self.PerfMeasure = struct;

      % Initialize triggers.
      self.InitTriggers();
    end
    
    function delete(self)
      % Destructor.
      clear self.AssetMgr;
      clear self.AlgoParams;
      clear self.Triggers;
      clear self.TriggersData;
      clear self.PerfMeasure;
    end

    function InitTriggers(self)
      % == TrendTradeTrig ==
      % Trade when the trend changes.
      self.Triggers{end + 1} = 'TrendTradeTrig';
      self.TriggersData.TrendTradeTrig = struct('tick_count_buy', 0, 'tick_count_sell', 0);

      % == ReducePositionTrig ==
      %self.Triggers{end + 1} = 'TradeMatchTrig';
      self.TriggersData.TradeMatchTrig = struct('tick_count', 0);

      % == Detect Trends ==
      % Double exponential smoothing for now.
      % TODO: forecasting and back fitting?
      % https://grisha.org/blog/2016/01/29/triple-exponential-smoothing-forecasting/
      self.Triggers{end + 1} = 'TrendDetectionTrig';
      self.TriggersData.TrendDetectionTrig = struct;

      for isin = self.AssetMgr.ISINs
        isin = isin{1};
        [self.TriggersData.TrendDetectionTrig(:).(isin)] = struct('c_ask', [0.05, 0.08, 0.12], 'l_ask', [], 'b_ask', [], 'b2_ask', [], 'c_bid', [0.05, 0.08, 0.12], 'l_bid', [], 'b_bid', [], 'b2_bid', []);
      end
    end

    function HandleDepthUpdate(self, ~, aDepth)
      % First the new book is stored.
      self.AssetMgr.UpdateDepths(aDepth);
 
      % Run trigger functions.
      self.HandleTriggers();
    end

    function HandleTriggers(self)
      for trig = self.Triggers
        % fprintf('Trig: %s\n', trig{1})
        self.(trig{1})();
      end
    end

    function theIdx = CheckActiveTrades(self, aISIN, aP, aSide)
      for i = 1:length(self.AssetMgr.ActiveTrades.(aISIN))
        trade = self.AssetMgr.ActiveTrades.(aISIN){i};
        if trade.volume(1)*aSide < 0
          continue
        end

        myExpectedProfit = abs(sum(trade.volume)) * aP;
        
        if aSide * myExpectedProfit > aSide * abs(sum(trade.volume .* trade.price))
          theIdx = i;
          return
        end
      end
      theIdx = 0;
    end

    % Buy when movmean(S_ask, [lookback 0]) < S_bid for dtbmax ticks.
    function TrendTradeTrig(self)
      for isin = self.AssetMgr.ISINs
        isin = isin{1};

        myData = self.AssetMgr.GetDataFromHistory(isin, {'askLimitPrice', 'askVolume', 'bidLimitPrice', 'bidVolume'}, 0);

        if ~any(cellfun(@isempty, myData.askLimitPrice)) && ~any(cellfun(@isempty, myData.bidLimitPrice))
          if length(self.TriggersData.TrendDetectionTrig.(isin).b2_ask) > 1 
            % Check when we are at a minimum (d2V > 0, dV == 0)
            if self.TriggersData.TrendDetectionTrig.(isin).b2_ask(end) > 0 && self.TriggersData.TrendDetectionTrig.(isin).b_ask(end)*self.TriggersData.TrendDetectionTrig.(isin).b_ask(end-1) < 0
              
              myPos = self.AssetMgr.GetISINPosition(isin);
              myVol = min(max(0, self.AlgoParams.max_trading_volume.(isin) - myPos), myData.askVolume{1}(1));
              
              if myVol > 0
                
                % Check if we have any trades that can be improved.
                myIdx = self.CheckActiveTrades(isin, myData.askLimitPrice{1}(1), -1)
                myTradedVolume = 0;

                if myIdx && ~isempty(self.AssetMgr.ActiveTrades.(isin))
                  trade = self.AssetMgr.ActiveTrades.(isin){myIdx};
                  % Buy enough to complete the trade.
                  myTradePos = abs(sum(self.AssetMgr.ActiveTrades.(isin){myIdx}.volume));
                  myTrades = self.Trade(isin, myData.askLimitPrice{1}(1), min(myTradePos, myVol));
                  fprintf('Before -- Trade: %3d, Pos: %3.0f, Profit: %5.2f\n', myIdx, myTradePos, -sum(trade.price .* trade.volume));

                  if myTrades
                    fprintf('\nTrendTradeTrig - Buy (complete) \n');
                    myTradedVolume = self.ownTrades.side(end-myTrades+1:end) .* self.ownTrades.volume(end-myTrades+1:end);
                    self.AssetMgr.UpdateTrade(isin, myIdx, self.ownTrades.price(end-myTrades+1:end), myTradedVolume);
                    self.AssetMgr.ArchiveCompletedTrades();
                  end
                  fprintf('After -- Trade: %3d, Pos: %3.0f, Profit: %5.2f\n', myIdx, sum(self.AssetMgr.ActiveTrades.(isin){myIdx}.volume), -sum(self.AssetMgr.ActiveTrades.(isin){myIdx}.price .* self.AssetMgr.ActiveTrades.(isin){myIdx}.volume));
                end
                
                if myVol - myTradedVolume > 0 && isempty(self.AssetMgr.ActiveTrades.(isin))
                  myTrades = self.Trade(isin, myData.askLimitPrice{1}(1), myVol - myTradedVolume);
                  if myTrades
                    fprintf('\nTrendTradeTrig - Buy (new) \n');
                    self.AssetMgr.GenerateNewTrade(isin, self.ownTrades.price(end), self.ownTrades.side(end)*self.ownTrades.volume(end));
                  end
                end
              end
            end
          end

          if length(self.TriggersData.TrendDetectionTrig.(isin).b2_bid) > 1
            if self.TriggersData.TrendDetectionTrig.(isin).b2_bid(end) < 0 && self.TriggersData.TrendDetectionTrig.(isin).b_bid(end)*self.TriggersData.TrendDetectionTrig.(isin).b_bid(end-1) < 0
              myPos = self.AssetMgr.GetISINPosition(isin);
              myVol = min(max(0, self.AlgoParams.max_trading_volume.(isin) + myPos), myData.bidVolume{1}(1));
            
              if myVol > 0
                % Check if we have any trades that can be improved.
                myIdx = self.CheckActiveTrades(isin, myData.bidLimitPrice{1}(1), 1)
                myTradedVolume = 0;

                if myIdx && ~isempty(self.AssetMgr.ActiveTrades.(isin))
                  % Sell enough to complete the trade.
                  trade = self.AssetMgr.ActiveTrades.(isin){myIdx};
                  myTradePos = abs(sum(self.AssetMgr.ActiveTrades.(isin){myIdx}.volume));

                  fprintf('Before -- Trade: %3d, Pos: %3.0f, Profit: %5.2f\n', myIdx, myTradePos, -sum(trade.price .* trade.volume));
                  myTrades = self.Trade(isin, myData.bidLimitPrice{1}(1), -min(myTradePos, myVol));

                  if myTrades
                    fprintf('\nTrendTradeTrig - Sell (complete) \n');
                    % myTradedVolume is negative.
                    myTradedVolume = self.ownTrades.side(end-myTrades+1:end) .* self.ownTrades.volume(end-myTrades+1:end);
                    self.AssetMgr.UpdateTrade(isin, myIdx, self.ownTrades.price(end-myTrades+1:end), myTradedVolume);
                    self.AssetMgr.ArchiveCompletedTrades();
                  end
                  fprintf('After -- Trade: %3d, Pos: %3.0f, Profit: %5.2f\n', myIdx, sum(self.AssetMgr.ActiveTrades.(isin){myIdx}.volume), -sum(self.AssetMgr.ActiveTrades.(isin){myIdx}.price .* self.AssetMgr.ActiveTrades.(isin){myIdx}.volume));
                end
                
                if myVol + myTradedVolume > 0 && isempty(self.AssetMgr.ActiveTrades.(isin))
                  myTrades = self.Trade(isin, myData.bidLimitPrice{1}(1), - myVol - myTradedVolume);
                  if myTrades
                    fprintf('\nTrendTradeTrig - Sell (new) \n');
                    self.AssetMgr.GenerateNewTrade(isin, self.ownTrades.price(end), self.ownTrades.side(end)*self.ownTrades.volume(end));
                  end
                end
              end
            end
          end
        end
      end
      self.AssetMgr.ArchiveCompletedTrades();
    end

    function TradeMatchTrig(self)
      for isin = self.AssetMgr.ISINs
        isin = isin{1};

        for i = 1:length(self.AssetMgr.ActiveTrades.(isin))
          trade = self.AssetMgr.ActiveTrades.(isin){i};

          myPos = sum(trade.volume);
          if myPos < 0
            myLabels = {'askLimitPrice', 'askVolume'};
          else
            myLabels = {'bidLimitPrice', 'bidVolume'};
          end

          myData = self.AssetMgr.GetDataFromHistory(isin, myLabels, 0);

          if length(myData.(myLabels{1}){1})
            if myData.(myLabels{1}){1}(1) > trade.price(1)
              fprintf('Before -- Trade: %3d, Pos: %3.0f, Profit: %5.2f\n', i, myPos, -sign(myPos)*sum(trade.price .* trade.volume));

              myTrades = self.Trade(isin, myData.(myLabels{1}){1}(1), -min(myPos, myData.(myLabels{2}){1}(1)));

              self.AssetMgr.ActiveTrades.(isin){i}.price = [ self.AssetMgr.ActiveTrades.(isin){i}.price ; self.ownTrades.price(end-myTrades+1:end) ];

              self.AssetMgr.ActiveTrades.(isin){i}.volume = [ self.AssetMgr.ActiveTrades.(isin){i}.volume ; self.ownTrades.side(end-myTrades+1:end).*self.ownTrades.volume(end-myTrades+1:end) ];

              fprintf('After -- Trade: %3d, Pos: %3.0f, Profit: %5.2f\n', i, sum(self.AssetMgr.ActiveTrades.(isin){i}.volume), - sign(myPos) * sum(self.AssetMgr.ActiveTrades.(isin){i}.price .* self.AssetMgr.ActiveTrades.(isin){i}.volume));
            end
          end
        end
      end

      % fprintf('Before. Active: %d, Completed: %d\n', sum(cellfun(@(isin) length(self.AssetMgr.ActiveTrades.(isin)), self.AssetMgr.ISINs)), sum(cellfun(@(isin) length(self.AssetMgr.CompletedTrades.(isin)), self.AssetMgr.ISINs)))
      self.AssetMgr.ArchiveCompletedTrades();
      % fprintf('After. Active: %d, Completed: %d\n', sum(cellfun(@(isin) length(self.AssetMgr.ActiveTrades.(isin)), self.AssetMgr.ISINs)), sum(cellfun(@(isin) length(self.AssetMgr.CompletedTrades.(isin)), self.AssetMgr.ISINs)))
    end 

    function TrendDetectionTrig(self)
      for isin = self.AssetMgr.ISINs
        isin = isin{1};

        alpha_ask = self.TriggersData.TrendDetectionTrig.(isin).c_ask(1);
        beta_ask = self.TriggersData.TrendDetectionTrig.(isin).c_ask(2);
        gamma_ask = self.TriggersData.TrendDetectionTrig.(isin).c_ask(3);

        alpha_bid = self.TriggersData.TrendDetectionTrig.(isin).c_bid(1);
        beta_bid = self.TriggersData.TrendDetectionTrig.(isin).c_bid(2);
        gamma_bid = self.TriggersData.TrendDetectionTrig.(isin).c_bid(3);

        myData = self.AssetMgr.GetDataFromHistory(isin, {'askLimitPrice', 'askVolume', 'bidLimitPrice', 'bidVolume'}, 0);

        if ~any(cellfun(@isempty, myData.askLimitPrice))
          if length(self.TriggersData.TrendDetectionTrig.(isin).l_ask) == 0
            self.TriggersData.TrendDetectionTrig.(isin).l_ask(1) = myData.askLimitPrice{1}(1);
            self.TriggersData.TrendDetectionTrig.(isin).b_ask(1) = 0.0;
            self.TriggersData.TrendDetectionTrig.(isin).b2_ask(1) = 0.0;
          elseif length(self.TriggersData.TrendDetectionTrig.(isin).l_ask) == 1
            self.TriggersData.TrendDetectionTrig.(isin).l_ask(2) = myData.askLimitPrice{1}(1);
            self.TriggersData.TrendDetectionTrig.(isin).b_ask(2) = myData.askLimitPrice{1}(1) - self.TriggersData.TrendDetectionTrig.(isin).l_ask(1);
            self.TriggersData.TrendDetectionTrig.(isin).b2_ask(2) = self.TriggersData.TrendDetectionTrig.(isin).b_ask(2);
          end

          if length(self.TriggersData.TrendDetectionTrig.(isin).l_ask) > 1
            % Update level
            self.TriggersData.TrendDetectionTrig.(isin).l_ask(end+1) = alpha_ask * myData.askLimitPrice{1}(1) + (1 - alpha_ask) * (self.TriggersData.TrendDetectionTrig.(isin).l_ask(end) + self.TriggersData.TrendDetectionTrig.(isin).b_ask(end));

            % Update trend
            self.TriggersData.TrendDetectionTrig.(isin).b_ask(end+1) = beta_ask * ( self.TriggersData.TrendDetectionTrig.(isin).l_ask(end) - self.TriggersData.TrendDetectionTrig.(isin).l_ask(end-1) ) + ( 1 - beta_ask ) * self.TriggersData.TrendDetectionTrig.(isin).b_ask(end);

            % Update trend's trend
            self.TriggersData.TrendDetectionTrig.(isin).b2_ask(end+1) = gamma_ask * ( self.TriggersData.TrendDetectionTrig.(isin).b_ask(end) - self.TriggersData.TrendDetectionTrig.(isin).b_ask(end-1) ) + (1 - gamma_ask) * self.TriggersData.TrendDetectionTrig.(isin).b2_ask(end);
          end
        end

        if ~any(cellfun(@isempty, myData.bidLimitPrice))
          if length(self.TriggersData.TrendDetectionTrig.(isin).l_bid) == 0
            self.TriggersData.TrendDetectionTrig.(isin).l_bid(1) = myData.bidLimitPrice{1}(1);
            self.TriggersData.TrendDetectionTrig.(isin).b_bid(1) = 0.0;
            self.TriggersData.TrendDetectionTrig.(isin).b2_bid(1) = 0.0;
          elseif length(self.TriggersData.TrendDetectionTrig.(isin).l_bid) == 1
            self.TriggersData.TrendDetectionTrig.(isin).l_bid(2) = myData.bidLimitPrice{1}(1);
            self.TriggersData.TrendDetectionTrig.(isin).b_bid(2) = myData.bidLimitPrice{1}(1) - self.TriggersData.TrendDetectionTrig.(isin).l_bid(1);
            self.TriggersData.TrendDetectionTrig.(isin).b2_bid(2) = self.TriggersData.TrendDetectionTrig.(isin).b_bid(2);
          end

          if length(self.TriggersData.TrendDetectionTrig.(isin).l_bid) > 1
            % Update level
            self.TriggersData.TrendDetectionTrig.(isin).l_bid(end+1) = alpha_bid * myData.bidLimitPrice{1}(1) + (1 - alpha_bid) * (self.TriggersData.TrendDetectionTrig.(isin).l_bid(end) + self.TriggersData.TrendDetectionTrig.(isin).b_bid(end));

            % Update trend
            self.TriggersData.TrendDetectionTrig.(isin).b_bid(end+1) = beta_bid * ( self.TriggersData.TrendDetectionTrig.(isin).l_bid(end) - self.TriggersData.TrendDetectionTrig.(isin).l_bid(end-1) ) + ( 1 - beta_bid ) * self.TriggersData.TrendDetectionTrig.(isin).b_bid(end);

            % Update trend's trend
            self.TriggersData.TrendDetectionTrig.(isin).b2_bid(end+1) = gamma_bid * ( self.TriggersData.TrendDetectionTrig.(isin).b_bid(end) - self.TriggersData.TrendDetectionTrig.(isin).b_bid(end-1) ) + (1 - gamma_bid) * self.TriggersData.TrendDetectionTrig.(isin).b2_bid(end);
          end
        end

        % fprintf('%d -- (%7s) l_ask: %5.2f, b_ask: %6.4f, b2_ask: %6.4f, l_bid: %5.2f, b_bid: %6.4f, b2_bid: %6.4f\n', self.AssetMgr.CurrentIndex.total, isin, self.TriggersData.TrendDetectionTrig.(isin).l_ask(end), self.TriggersData.TrendDetectionTrig.(isin).b_ask(end), self.TriggersData.TrendDetectionTrig.(isin).b2_ask(end), self.TriggersData.TrendDetectionTrig.(isin).l_bid(end), self.TriggersData.TrendDetectionTrig.(isin).b_bid(end), self.TriggersData.TrendDetectionTrig.(isin).b2_bid(end))
      end
    end

    function thePrice = GetVolumePrice(~, aP, aV, aLimitVol)
      % Computes the average price of purchasing a volume `aLimitVol`.
      myVcs = cumsum(aV);
      myIndex = myVcs < aLimitVol;
      myNextIndex = find(~myIndex, 1);
      thePrice = (sum(aP(myIndex) .* aV(myIndex)) + aP(myNextIndex) * (aLimitVol - myVcs(myNextIndex)) / aLimitVol);
    end

    function theConfirmation = Trade(self, aISIN, aP, aV)
      % Helper function for buying (aV > 0) and selling (aV < 0) stock.
      % Returns whether the order was successful or not.
      myCurrentTrades = length(self.ownTrades.price);
      self.SendNewOrder(aP, abs(aV), sign(aV), {aISIN}, {'IMMEDIATE'}, 0);
      myTradeCount = length(self.ownTrades.price) - myCurrentTrades;
      theConfirmation = myTradeCount;
 
      myLabels = {'askVolume', 'bidVolume'};

      myData = self.AssetMgr.ComputeDataFromHistory(aISIN, myLabels, 0, { @sum, @sum });

      fprintf('Trade info: %7s, %5.2f, %3.0f. MaxVol: %3.0f/%3.0f\n', aISIN, aP, aV, myData.(myLabels{1}){end}, myData.(myLabels{2}){end});
      % Here we iterate over all the trades done (in case aV > first entry's volume),
      % updating our assets and book.
      for i = 1:myTradeCount
        fprintf('Trade: %5.2f, %3.0f - ', self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
        if theConfirmation
          fprintf('Correct.\n');
          self.AssetMgr.UpdateAssets(aISIN, self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
          fprintf('Profit (%7s): %5.2f, total: %5.2f\n', aISIN, self.AssetMgr.GetISINProfit(aISIN), self.AssetMgr.GetTotalProfit());
        end
      end
      fprintf('\n')
    end

    function TradeFullStock(self, aISIN, aV)
      % Try to buy/sell the volume aV.
      if aV > 0
        myLabels = {'askLimitPrice', 'askVolume'};
      else
        myLabels = {'bidLimitPrice', 'bidVolume'};
      end

      myData = self.AssetMgr.GetDataFromHistory(aISIN, myLabels, 0);
      if length(myData.(myLabels{1}){end}) && length(myData.(myLabels{2}){end})
        self.Trade(aISIN, myData.(myLabels{1}){end}(end), aV);
      end
    end

    function Unwind(self)
      % Sell sell sell!!
      for isin = self.AssetMgr.ISINs
        isin = isin{1};
        myPos = self.AssetMgr.GetISINPosition(isin);
        self.TradeFullStock(isin, -myPos)
      end

      fprintf('Total updates: %d\n', self.AssetMgr.CurrentIndex.total)
      %self.AssetMgr.delete();
    end
  end
end
