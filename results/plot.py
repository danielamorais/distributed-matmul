import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

requests = pd.read_csv("dana_requests.csv")
requests_serial = pd.read_csv("serial_requests.csv")
requests_serial['app'] = 'Serial'
requests['app'] = 'Distributed'
combined_data = pd.concat([requests, requests_serial], axis=0, ignore_index=True)
sns.stripplot(data=combined_data, x='Response Time (ms)', y='app')
plt.title('Response time Distributed x Serial')
plt.show()


requests['time'] = range(len(requests))
requests_serial['time'] = range(len(requests_serial))
sns.lineplot(data=requests, x='time', y='Response Time (ms)', label="Distributed")
sns.lineplot(data=requests_serial, x='time', y='Response Time (ms)', label="Serial")
plt.title('Response time Distributed x Serial')
plt.legend()
plt.show()
