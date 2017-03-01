import numpy as np
import matplotlib.pylab as plt
oP=np.array([1.1102e-16,0.012294,0.024629,0.036336,0.048955,0.061425,0.073886,0.087384,0.098158,0.10868,0.12462,0.13455,0.14858,0.16264,0.17607,0.18446,0.20388,0.21771,0.22978,0.23957,0.25838,0.27008,0.28169,0.29456,0.30782,0.32609,0.34338,0.358,0.36751,0.38788,0.40362,0.41669,0.43015,0.44432,0.45217,0.48171,0.4888,0.49872,0.53788,0.55504,0.55253,0.57045,0.58395,0.6109,0.62287,0.62966,0.65131,0.68102,0.68669,0.70293,0.71378,0.74702,0.75274,0.77273,0.81023,0.82679,0.83982,0.85936,0.90009,0.91548,0.9078,0.94174,0.96637,1.005,1.0316,1.0582,1.0685,1.0858,1.1231,1.141,1.1689,1.2031,1.2209,1.2415,1.2524,1.3172,1.332,1.3677,1.4015,1.4378,1.4853,1.5507,1.5898,1.5976,1.6551,1.6983,1.7579,1.8269,1.8701,1.9345,1.9657,2.0661,2.1454,2.2425,2.3422,2.4871,2.6208,2.8357,3.1317,1000])
P=np.array([0,0.010101,0.020202,0.030303,0.040404,0.050505,0.060606,0.070707,0.080808,0.090909,0.10101,0.11111,0.12121,0.13131,0.14141,0.15152,0.16162,0.17172,0.18182,0.19192,0.20202,0.21212,0.22222,0.23232,0.24242,0.25253,0.26263,0.27273,0.28283,0.29293,0.30303,0.31313,0.32323,0.33333,0.34343,0.35354,0.36364,0.37374,0.38384,0.39394,0.40404,0.41414,0.42424,0.43434,0.44444,0.45455,0.46465,0.47475,0.48485,0.49495,0.50505,0.51515,0.52525,0.53535,0.54545,0.55556,0.56566,0.57576,0.58586,0.59596,0.60606,0.61616,0.62626,0.63636,0.64646,0.65657,0.66667,0.67677,0.68687,0.69697,0.70707,0.71717,0.72727,0.73737,0.74747,0.75758,0.76768,0.77778,0.78788,0.79798,0.80808,0.81818,0.82828,0.83838,0.84848,0.85859,0.86869,0.87879,0.88889,0.89899,0.90909,0.91919,0.92929,0.93939,0.94949,0.9596,0.9697,0.9798,0.9899,1.])
Profit=np.array([1,1.0008,1.0016,1.0024,1.0033,1.0041,1.0049,1.0058,1.0065,1.0072,1.0083,1.009,1.0099,1.0108,1.0117,1.0123,1.0136,1.0145,1.0153,1.016,1.0172,1.018,1.0188,1.0196,1.0205,1.0217,1.0229,1.0239,1.0245,1.0259,1.0269,1.0278,1.0287,1.0296,1.0301,1.0321,1.0326,1.0332,1.0359,1.037,1.0368,1.038,1.0389,1.0407,1.0415,1.042,1.0434,1.0454,1.0458,1.0469,1.0476,1.0498,1.0502,1.0515,1.054,1.0551,1.056,1.0573,1.06,1.061,1.0605,1.0628,1.0644,1.067,1.0688,1.0705,1.0712,1.0724,1.0749,1.0761,1.0779,1.0802,1.0814,1.0828,1.0835,1.0878,1.0888,1.0912,1.0934,1.0959,1.099,1.1034,1.106,1.1065,1.1103,1.1132,1.1172,1.1218,1.1247,1.129,1.131,1.1377,1.143,1.1495,1.1561,1.1658,1.1747,1.189,1.2088,1000])
plt.plot(P,oP,linewidth=5)
plt.axis([0,1,0,3])
plt.grid()
plt.xlabel("Risk",fontsize=16)
plt.ylabel("Reward",fontsize=16)
plt.title("")
plt.tick_params(labelsize=13)
plt.savefig("PoPplot.eps",dpi=300,bbox_inches='tight')
plt.show()

plt.plot(P,Profit,linewidth=5)
plt.axis([0,1,1,1.4])
plt.grid()
plt.xlabel("Risk",fontsize=16)
plt.ylabel("Increase in investment (factor)",fontsize=16)
plt.title("")
plt.tick_params(labelsize=13)
plt.savefig("PProfitplot.eps",dpi=300,bbox_inches='tight')
plt.show()
