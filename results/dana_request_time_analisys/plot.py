import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

sds_label = "Self Distributed System"
local_label = "Local (one instance)"
data_ordering = "Test instant (seconds)"

stats_history = pd.read_csv("data/dana_stats_history.csv")
stats_history_serial = pd.read_csv("data/serial_stats_history.csv")
stats_history_serial[data_ordering] = range(len(stats_history_serial))
stats_history[data_ordering] = range(len(stats_history))

sns.lineplot(data=stats_history, x=data_ordering, y='Requests/s', label=sds_label)
sns.lineplot(data=stats_history_serial, x=data_ordering, y='Requests/s', label=local_label)
plt.title('Responses/s ' +  sds_label + ' x ' +  local_label)
plt.legend()
plt.show()

requests = pd.read_csv("dana_requests.csv")
requests_serial = pd.read_csv("serial_requests.csv")
requests_serial['app'] = 'Serial'
requests['app'] = 'Distributed'
combined_data = pd.concat([requests, requests_serial], axis=0, ignore_index=True)

sns.stripplot(data=combined_data, x='Response Time (ms)', y='app')
plt.title('Response time ' +  sds_label + ' x ' +  local_label)
plt.show()


requests[data_ordering] = range(len(requests))
requests_serial[data_ordering] = range(len(requests_serial))
sns.lineplot(data=requests, x=data_ordering, y='Response Time (ms)', label=sds_label)
sns.lineplot(data=requests_serial, x=data_ordering, y='Response Time (ms)', label=local_label)
plt.title('Response time ' +  sds_label + ' x ' +  local_label)
plt.legend()
plt.show()

requests_media = requests.groupby('Timestamp')['Response Time (ms)'].mean().reset_index()
requests_serial_media = requests_serial.groupby('Timestamp')['Response Time (ms)'].mean().reset_index()
sns.lineplot(data=requests, x='Timestamp', y='Response Time (ms)', label=sds_label)
sns.lineplot(data=requests_serial, x='Timestamp', y='Response Time (ms)', label=local_label)
plt.title('Response time (avarage) ' +  sds_label + ' x ' +  local_label)
plt.legend()
plt.show()