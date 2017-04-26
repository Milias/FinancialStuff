classdef TradingRobot < AutoTrader
  properties
    AssetMgr
    AlgoParams
    Triggers
    TriggersData
    PerfMeasure

    Profiling
  end

  methods
    function self = TradingRobot
      % Profiler used to measure performance.
      self.Profiling = Profiler;

      self.Profiling.StartTimer('Initialize')
      % This struct contains basic parameters of the algorithm.
      % max_trading_volume :    maximum amount of shares to hold at any given tick.
      % lookback :              number of past ticks to consider for computations.
      % trigger_params :        several parameters used mainly for triggers.1
      %   dtsmax :              number of ticks we wait before selling stock.
      %   dtbmax :              number of ticks we wait before buying stock.
      %   dthmax :              maximum ticks we hold to the stock.
      %   dssmax :              maximum change of the stock's price before selling.
      %   dsbmax :              change in price before buying.
      self.AlgoParams = struct('max_pos', struct, 'lookback', 100, 'init_size', 40000, 'max_lag_window', 150);

      % Initializing the assets manager with the two ISINs.
      self.AssetMgr = AssetManager(self.AlgoParams.init_size);
      self.AssetMgr.Init({'DBK_EUR', 'CBK_EUR'});

      % Maximum total position we can get by creating new trades.
      self.AlgoParams.max_pos.new.DBK_EUR = 100;
      self.AlgoParams.max_pos.new.CBK_EUR = 100;

      % Maximum active position we can get.
      self.AlgoParams.max_pos.act.DBK_EUR = 300; %@(t) (t<20000)*2000 + (t>=20000&&t<30000)*(5900 - 0.195 * t) + (t>=30000)*50;
      self.AlgoParams.max_pos.act.CBK_EUR = 300; %@(t) (t<20000)*2000 + (t>=20000&&t<30000)*(5900 - 0.195 * t) + (t>=30000)*50;

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
      self.Profiling.StopTimer('Initialize')
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
      % Here the triggers are defined. Each trigger is a function that will be called after each
      % book update, in order. self.Triggers holds the name of the method and self.TriggersData 
      % holds extra information for each trigger.

      % == Detect Trends ==
      % Double exponential smoothing for now with weighted second derivative.
      %
      % TODO: forecasting and back fitting?
      % https://grisha.org/blog/2016/01/29/triple-exponential-smoothing-forecasting/
      % The number of elements on each cell array should be equal to the vector
      % dimensions of the function self.Valuate().
      %
      % TODO: weighted average of book prices with volumes. Introducing more parameters.
      self.Triggers{end + 1} = 'TrendDetectionTrig';
      self.TriggersData.TrendDetectionTrig = struct;

      % In the following lines we define the functions used in self.Valuate().
      %   1. The field used to compute the value. Should be deprecated.
      %   2. Functions to apply to each book, returning: price of the first entries of the book, both ask and bid (twice) and sum of volumes.
      %   3. Finally we define the default value returned in case the book is empty.
      self.TriggersData.TrendDetectionTrig.DataLabels = {'askLimitPrice', 'bidLimitPrice', 'askLimitPrice', 'bidLimitPrice', 'askVolume', 'bidVolume'};

      self.TriggersData.TrendDetectionTrig.DataFunctions = {@(data) min(data.askLimitPrice), @(data) max(data.bidLimitPrice),  @(data) min(data.askLimitPrice), @(data) max(data.bidLimitPrice), @(data) sum(data.askVolume), @(data) sum(data.bidVolume)};

      self.TriggersData.TrendDetectionTrig.DataDefaults = {nan, nan, nan, nan, 0, 0};

      % Initializing cell arrays to store weighted averages.
      self.TriggersData.TrendDetectionTrig.wa = cell(self.AlgoParams.init_size, length(self.AssetMgr.ISINs));
      self.TriggersData.TrendDetectionTrig.coef = cell(1, length(self.AssetMgr.ISINs));
      self.TriggersData.TrendDetectionTrig.lag = zeros(self.AlgoParams.init_size, 1);

      % These are the values used to compute the double exponential smoothing forecasting, respectively associated with the values returned by the previous functions. Specifically, [a b c]: a refers to the smoothed value, b refers to the smooth first derivative, and c to the second derivative. [ 1 0 0 ] means we are just storing the real value coming from the function.
      for i = 1:length(self.AssetMgr.ISINs)
        self.TriggersData.TrendDetectionTrig.coef{1,i} = [0.1 0.15 0.8 ; 0.1 0.15 0.8 ; 1 0 0 ; 1 0 0 ; 1 0 0 ; 1 0 0];
      end

      % Combination of indices we'll use later to compute the self.Valuate() functions.
      [self.TriggersData.Global.Valuate.I, self.TriggersData.Global.Valuate.J] = ndgrid(1:length(self.AssetMgr.ISINs), 1:length(self.TriggersData.TrendDetectionTrig.DataLabels));

      % == TrendTradeTrig ==
      % Trade when the trend changes.
      self.Triggers{end + 1} = 'TrendTradeTrig';
      self.TriggersData.TrendTradeTrig = struct('tick_count_buy', 0, 'tick_count_sell', 0);

      % == StopLossTrig ==
      % Compute how much losses each active trade is having.
      % If after 'holding_time' book updates, we are losing more than 'lost_value',
      % try to nullify the position.
      %self.Triggers{end + 1} = 'StopLossTrig';
      self.TriggersData.StopLossTrig = struct('holding_time', 600, 'lost_value', 0.99);

      % == CorrTrig ==
      self.Triggers{end + 1} = 'CorrTrig';
      self.TriggersData.CorrTrig = struct;
    end

    function HandleDepthUpdate(self, ~, aDepth)
      % First the new book is stored.
      self.Profiling.StartTimer('UpdateDepths')
      self.AssetMgr.UpdateDepths(aDepth);
      self.Profiling.StopTimer('UpdateDepths')

      % Run trigger functions.
      self.HandleTriggers();
    end

    function HandleTriggers(self)
      for trig = self.Triggers
        % fprintf('Trig: %s\n', trig{1})
        self.Profiling.StartTimer(trig{1});
        self.(trig{1})();
        self.Profiling.StopTimer(trig{1});
      end
    end

    % Function that returns a list of the expected profits of each active trade,
    % assuming a fixed price aP at which the remaining volume will be sold. If
    % the profit is negative then it returns zero, or if the side of the transaction
    % is not the one specified.
    function theProfits = CheckActiveTrades(self, aISIN, aP, aSide)
      % Returns profit from each trade.
      theProfits = zeros(length(self.AssetMgr.ActiveTrades.(aISIN)), 1);

      for i = 1:length(self.AssetMgr.ActiveTrades.(aISIN))
        trade = self.AssetMgr.ActiveTrades.(aISIN){i};
        theProfits(i, :) = (trade.volume(1) * aSide > 0) * max(0, sum(trade.volume) * aP - sum(trade.volume .* trade.price));
      end
    end

    
    function TrendTradeTrig(self)
      % Wait until we have enough data.
      if self.AssetMgr.CurrentIndex.total < 2
        return
      end

      for i = 1:length(self.AssetMgr.ISINs)
        isin = self.AssetMgr.ISINs{i};

        % Get the last book.
        myData = self.AssetMgr.GetDataFromHistory(isin);

        % WTB
        if ~isempty(myData.askLimitPrice)
          myWA = self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total, i};
          myOldWA = self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total-1, i};
          myVol = myData.askVolume;
          mySide = -1;

          % Check minimum, d2S > 0 and dS == 0.
          if myWA(1, 3) > 0 && myOldWA(1, 2) * myWA(1, 2) < 0
            if ~isempty(self.AssetMgr.ActiveTrades.(isin))
              % Here we iterate over each entry of the book, computing the expected profits
              % of each active trade and getting rid of the position if it's profitable.

              for k = 1:length(myData.askLimitPrice)
                myTrades = 0;
                myPrice = myData.askLimitPrice(k);

                % We have to check each entry for a profitable price.
                myProfits = self.CheckActiveTrades(isin, myData.askLimitPrice(k), mySide);

                % If there are no profits exit the loop, since the next entry will give even
                % lower values (more negative).
                if ~nnz(myProfits)
                  break
                end

                % And sort them.
                [mySortedProfits, mySortedIdx] = sort(myProfits, 'descend');

                for j = 1:nnz(myProfits)
                  % Now, for each trade we try to buy (in this case) as much as we can
                  % to fulfill the trade.
                  trade = self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)};
                  myVolToTrade = min(myVol(k), abs(sum(trade.volume)));

                  fprintf('TrendTradeTrig - WTB (complete)\n');

                  myTrades = self.Trade(isin, myPrice, - mySide * myVolToTrade);

                  if myTrades
                    fprintf('Trade: %s, Before Pos: %3.0f, ', trade.uuid, sum(trade.volume));

                    myTradedVolume = self.ownTrades.side(end-myTrades+1:end) .* self.ownTrades.volume(end-myTrades+1:end);
                    self.AssetMgr.UpdateTrade(isin, mySortedIdx(j), self.ownTrades.price(end-myTrades+1:end), myTradedVolume);
                    % If we do trade, we need to update the remaining volume available in the book.
                    myVol(k) = myVol(k) - abs(sum(myTradedVolume));

                    fprintf('After Pos: %3.0f, Profit: %6.2f\n', sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume), -sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.price .* self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume));

                    fprintf('\n')
                  end

                  % If the book entry is fulfilled, break.
                  if myVol(k) < 0.001
                    break
                  end
                end

                % If we did trade, print some information and update the completed trades.
                if myTrades
                  self.AssetMgr.PrintActivePosition();
                  self.AssetMgr.ArchiveCompletedTrades();
                end
              end
            end

            % Create new trades from the cheapest entry in the book, if there is any volume left.
            myVolToTrade = min([myVol(1), max(0, self.AlgoParams.max_pos.new.(isin) + mySide*self.AssetMgr.GetISINPosition(isin)), max(0, self.AlgoParams.max_pos.act.(isin) + mySide*self.AssetMgr.GetActivePosition(isin, -mySide))]);

            if myVolToTrade > 0.001 %&& isempty(self.AssetMgr.ActiveTrades.(isin))
              fprintf('TrendTradeTrig - WTB (new)\n');

              myTrades = self.Trade(isin, myData.askLimitPrice(1), myVolToTrade);
              if myTrades

                self.AssetMgr.GenerateNewTrade(isin, self.ownTrades.price(end-myTrades+1:end), self.ownTrades.side(end-myTrades+1:end).*self.ownTrades.volume(end-myTrades+1:end));

                self.AssetMgr.PrintActivePosition();

                fprintf('\n')
              end
            end

          end
        end

        % WTS
        % Basically the same as the previous situation.
        if ~isempty(myData.bidLimitPrice)
          myWA = self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total, i};
          myOldWA = self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total-1, i};
          myVol = myData.bidVolume;
          mySide = 1;

          % Check maximum, d2S < 0 and dS == 0.
          if myWA(2, 3) < 0 && myOldWA(2, 2) * myWA(2, 2) < 0
            if ~isempty(self.AssetMgr.ActiveTrades.(isin))

              for k = 1:length(myData.bidLimitPrice)
                myTrades = 0;
                myPrice = myData.bidLimitPrice(k);

                % We have to check each entry for a profitable price.
                myProfits = self.CheckActiveTrades(isin, myPrice, mySide);

                if ~nnz(myProfits)
                  continue
                end

                % And sort them by column (first dimension).
                [mySortedProfits, mySortedIdx] = sort(myProfits, 'descend');

                for j = 1:nnz(myProfits)
                  trade = self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)};
                  myVolToTrade = min(myVol(k), abs(sum(trade.volume)));
                  fprintf('TrendTradeTrig - WTS (complete)\n');
                  myTrades = self.Trade(isin, myPrice, - mySide * myVolToTrade);

                  if myTrades
                    fprintf('Trade: %s, Before Pos: %3.0f, ', trade.uuid, sum(trade.volume));

                    myTradedVolume = self.ownTrades.side(end-myTrades+1:end) .* self.ownTrades.volume(end-myTrades+1:end);
                    self.AssetMgr.UpdateTrade(isin, mySortedIdx(j), self.ownTrades.price(end-myTrades+1:end), myTradedVolume);
                    myVol(k) = myVol(k) - abs(sum(myTradedVolume));

                    fprintf('After Pos: %3.0f, Profit: %6.2f\n', sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume), -sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.price .* self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume));

                    fprintf('\n')
                  end

                  if myVol(k) < 0.001
                    break
                  end
                end

                if myTrades
                  self.AssetMgr.PrintActivePosition();
                  self.AssetMgr.ArchiveCompletedTrades();
                end
              end
            end

            % Create new trades from the cheapest entry in the book, if there is any volume left.
            myVolToTrade = min([myVol(1), max(0, self.AlgoParams.max_pos.new.(isin) + mySide*self.AssetMgr.GetISINPosition(isin)), max(0, self.AlgoParams.max_pos.act.(isin) + mySide*self.AssetMgr.GetActivePosition(isin, -mySide))]);
            if myVolToTrade > 0.001 %&& isempty(self.AssetMgr.ActiveTrades.(isin))
              fprintf('TrendTradeTrig - WTS (new)\n');
              myTrades = self.Trade(isin, myData.bidLimitPrice(1), -myVolToTrade);
              if myTrades

                self.AssetMgr.GenerateNewTrade(isin, self.ownTrades.price(end-myTrades+1:end), self.ownTrades.side(end-myTrades+1:end).*self.ownTrades.volume(end-myTrades+1:end));

                self.AssetMgr.PrintActivePosition();

                fprintf('\n')
              end
            end
          end
        end

      end
    end

    function CorrTrig(self)
      % The data used to compute the correlations will be the real data processed by self.Valuate(),
      % so that there are no unusable values.
      %if self.AssetMgr.CurrentIndex.total < self.AlgoParams.max_lag_window || any(cellfun(@(isin) self.AssetMgr.CurrentIndex.(isin) < self.AlgoParams.max_lag_window, self.AssetMgr.ISINs))
      %  return
      %end

      %myData = arrayfun(@(i) self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total-self.AlgoParams.max_lag_window:self.AssetMgr.CurrentIndex.total, i}, 1:length(self.AssetMgr.ISINs));
    end

    % Trigger to compute after each book update several weighted averages given by self.Valuate().
    function TrendDetectionTrig(self)
      % First we get the new data.
      myData = self.Valuate();

      for j = 1:length(self.AssetMgr.ISINs)
        isin = self.AssetMgr.ISINs{j};

        % Coefficients used for the WA, that could be updated after each book update.
        myCoef = self.TriggersData.TrendDetectionTrig.coef{1, j};

        % If there is a previous WA, copy that one, otherwise initialize to zero.
        if self.AssetMgr.CurrentIndex.total > 2
          myOldWA = self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total-1, j};
        else
          myOldWA = zeros(size(self.TriggersData.TrendDetectionTrig.coef{1, j}) + [0 1]);
        end

        myWA = myOldWA;

        for i = 1:length(self.TriggersData.TrendDetectionTrig.DataFunctions)
          if ~isnan(myData(j, i))
            % Normal case: just compute the WA.
            if myOldWA(i, end) > 1
              myWA(i, 1) = myCoef(i, 1) * myData(j, i) + ( 1 - myCoef(i, 1) ) * ( myOldWA(i, 1) + myOldWA(i, 2) );
              myWA(i, 2) = myCoef(i, 2) * ( myWA(i, 1) - myOldWA(i, 1) ) + ( 1 - myCoef(i, 2) ) * myOldWA(i, 2);
              myWA(i, 3) = myCoef(i, 3) * ( myWA(i, 2) - myOldWA(i, 2) ) + ( 1 - myCoef(i, 3) ) * myOldWA(i, 3);
              myWA(i, end) = myOldWA(i, end) + 1;

            % Initial condition of the first and second derivatives.
            elseif myOldWA(i, end) == 1
              myWA(i, 1) = myData(j, i);
              myWA(i, 2) = myWA(i, 1) - myOldWA(i, 1);
              myWA(i, 3) = 0.0;
              myWA(i, end) = myOldWA(i, end) + 1;

            % Initial condition of the level.
            else
              myWA(i, 1) = myData(j, i);
              myWA(i, 2) = 0.0;
              myWA(i, 3) = 0.0;
              myWA(i, end) = myOldWA(i, end) + 1;
            end 
          end
        end
        self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total, j} = myWA;
      end

    end

    function theValues = Valuate(self)
      % Computes several values from the book that we will use to calculate trends.
      % If there are no entries in the book, return default.

      self.Profiling.StartTimer('Valuate')

      myData = cellfun(@(isin) self.AssetMgr.GetDataFromHistory(isin), self.AssetMgr.ISINs, 'UniformOutput', false);

      theValues = arrayfun(@(i, j) IfElseScalar(isempty(myData{i}.(self.TriggersData.TrendDetectionTrig.DataLabels{j})), self.TriggersData.TrendDetectionTrig.DataDefaults{j},  self.TriggersData.TrendDetectionTrig.DataFunctions{j}(myData{i})), self.TriggersData.Global.Valuate.I, self.TriggersData.Global.Valuate.J);

      self.Profiling.StopTimer('Valuate')
    end

    function StopLossTrig(self)
      % For each active trade, check if it's profitable. If it's not,
      % we will try to get rid of that position.
      for i = 1:length(self.AssetMgr.ISINs)
        isin = self.AssetMgr.ISINs{i};
        for j = 1:length(self.AssetMgr.ActiveTrades.(isin))
          %Only check after a certain holding time.
          if self.AssetMgr.CurrentIndex.total - self.AssetMgr.ActiveTrades.(isin){j}.time(1) > self.TriggersData.StopLossTrig.holding_time
            trade = self.AssetMgr.ActiveTrades.(isin){j};

            % We need to update the book after each possible trade.
            myData = self.AssetMgr.GetDataFromHistory(isin);
            if isempty(myData.askLimitPrice) || isempty(myData.bidLimitPrice)
              continue;
            end

            if trade.volume(1) > 0
              myPrice = myData.bidLimitPrice(1);
              myVol = -myData.bidVolume(1);
            else
              myPrice = myData.askLimitPrice(1);
              myVol = myData.askVolume(1);
            end

            % Checks that the relative price loss is smaller than the set value.
            if abs(sum(trade.volume)) * myPrice / abs(sum(trade.volume .* trade.price)) < self.TriggersData.StopLossTrig.lost_value
              myTrades = self.Trade(isin, myPrice, sign(myVol) *  min(abs(myVol), sum(trade.volume)));

              if myTrades
                fprintf('StopLossTrig\n');
                fprintf('Trade: %s, Before Pos: %3.0f, ', trade.uuid, sum(trade.volume));

                myTradedVolume = self.ownTrades.side(end-myTrades+1:end) .* self.ownTrades.volume(end-myTrades+1:end);
                self.AssetMgr.UpdateTrade(isin, j, self.ownTrades.price(end-myTrades+1:end), myTradedVolume);

                fprintf('After Pos: %3.0f, Profit: %6.2f\n', sum(self.AssetMgr.ActiveTrades.(isin){j}.volume), -sum(self.AssetMgr.ActiveTrades.(isin){j}.price .* self.AssetMgr.ActiveTrades.(isin){j}.volume));

                self.AssetMgr.PrintActivePosition();

                fprintf('\n')
              end
            end
          end
        end
      end
      self.AssetMgr.ArchiveCompletedTrades();
    end

    function theConfirmation = Trade(self, aISIN, aP, aV)
      % Helper function for buying (aV > 0) and selling (aV < 0) stock.
      % Returns whether the order was successful or not.
      self.Profiling.StartTimer('Trade')
      myCurrentTrades = length(self.ownTrades.price);
      self.SendNewOrder(aP, abs(aV), sign(aV), {aISIN}, {'IMMEDIATE'}, 0);
      theConfirmation = length(self.ownTrades.price) - myCurrentTrades;

      myData = self.AssetMgr.GetDataFromHistory(aISIN);

      fprintf('Trade info: %7s, %5.2f, %3.0f. MaxVol: %3.0f/%3.0f\n', aISIN, aP, aV, sum(myData.askVolume), sum(myData.bidVolume));
      % Here we iterate over all the trades done (in case aV > first entry's volume),
      % updating our assets and book.
      for i = 1:theConfirmation
        fprintf('Trade: %6.2f, %3.0f - Correct\n', self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
        self.AssetMgr.UpdateAssets(aISIN, self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
        fprintf('Profit (%7s): %6.2f, total: %6.2f\n', aISIN, self.AssetMgr.GetISINProfit(aISIN), self.AssetMgr.GetTotalProfit());
      end
      self.Profiling.StopTimer('Trade')
    end

    function TradeFullStock(self, aISIN, aV)
      % Try to buy/sell the volume aV.
      if aV > 0
        myLabels = {'askLimitPrice', 'askVolume'};
      else
        myLabels = {'bidLimitPrice', 'bidVolume'};
      end

      myData = self.AssetMgr.GetDataFromHistory(aISIN);
      if ~isempty(myData.(myLabels{1}))
        self.Trade(aISIN, myData.(myLabels{1})(end), aV);
      end
    end

    function Unwind(self)
      % Sell sell sell!!
      for isin = self.AssetMgr.ISINs
        isin = isin{1};
        myPos = self.AssetMgr.GetISINPosition(isin);
        self.TradeFullStock(isin, -myPos)
      end

      fprintf('\nCompleted trades profits:\n\n')
      myProfits = cellfun(@(isin) self.AssetMgr.GetComplProfit(isin), self.AssetMgr.ISINs);

      for i = 1:length(self.AssetMgr.ISINs)
        fprintf('%7s: %10.2f\n', self.AssetMgr.ISINs{i}, myProfits(i))
      end
      fprintf('  Total: %10.2f\n\n', sum(myProfits))

      fprintf('Active trades: %d\n\n', sum(cellfun(@(isin) length(self.AssetMgr.ActiveTrades.(isin)), self.AssetMgr.ISINs)))

      fprintf('Total updates: %d\n\n', self.AssetMgr.CurrentIndex.total)
      self.Profiling.PrintAll()
      fprintf('\n')
    end
  end
end

% Function used to compute the lag between two time series.
% If is not significant enough, return NaN.
function theLag = CorrTrig(x, y, n_window)
  [xcf, lags, bounds] = crosscorr(x, y, n_window, 3);
  [argVal, argMax] = max(xcf);
  if abs(argVal) < bounds(1)
    theLag = nan;
  else
    theLag = lags(argMax);
  end
end 
