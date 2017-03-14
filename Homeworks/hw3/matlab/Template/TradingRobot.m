classdef TradingRobot < AutoTrader
    properties
        EURDepth
        CHIDepth
    end

    methods
        function HandleDepthUpdate(aBot, ~, aDepth)
            % Saves last depth
            switch aDepth.ISIN
                case 'EUR_AKZA'; aBot.EURDepth = aDepth;
                case 'CHI_AKZA'; aBot.CHIDepth = aDepth;
            end
            % Try to arbitrage
            aBot.TryArbitrage();
        end

        function TryArbitrage(aBot)
            % NB These four variables contain dummy values
            myAskPrice  = 1;
            myBidPrice  = 100;
            myAskVolume = 1;
            myBidVolume = 1;

            aBot.SendNewOrder(myAskPrice, myAskVolume,  1, {'EUR_AKZA'}, {'IMMEDIATE'}, 0);
            aBot.SendNewOrder(myBidPrice, myBidVolume, -1, {'CHI_AKZA'}, {'IMMEDIATE'}, 0);
        end
    end
end
