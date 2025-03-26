import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

stats_history = pd.read_csv("dana_self_vs_serial/dana_stats_history.csv")
stats_history_serial = pd.read_csv("dana_self_vs_serial/serial_stats_history.csv")
stats_history_serial['time'] = range(len(stats_history_serial))
stats_history['time'] = range(len(stats_history))

sns.lineplot(data=stats_history, x='time', y='Requests/s', label="Distributed")
sns.lineplot(data=stats_history_serial, x='time', y='Requests/s', label="Serial")
plt.title('Requests/s Distributed x Serial')
plt.legend()
plt.show()

sns.lineplot(data=stats_history, x='time', y='Total Request Count', label="Distributed")
sns.lineplot(data=stats_history_serial, x='time', y='Total Request Count', label="Serial")
plt.title('Request Count Distributed x Serial')
plt.legend()
plt.show()

# sns.lineplot(data=stats_history, x='order', y='Failures/s', label="Dana")
# plt.title('Failure Count Dana')
# plt.legend()
# plt.show()

#Avarage response time distribution
requests = pd.read_csv("dana_self_vs_serial/dana_requests.csv")
requests_serial = pd.read_csv("dana_self_vs_serial/serial_requests.csv")
requests_serial['app'] = 'Serial'
requests['app'] = 'Distributed'
combined_data = pd.concat([requests, requests_serial], axis=0, ignore_index=True)
sns.stripplot(data=combined_data, x='Response Time (ms)', y='app')
plt.title('Response time Distributed x Serial')
plt.show()

# dana_requests = pd.read_csv("self_distribution/dana_requests.csv")
# dana_requests['order'] = range(len(dana_requests))
# sns.lineplot(data=dana_requests, x='order', y='response_time')
# plt.title('Request time to response Dana')
# plt.show()

# serial_requests = pd.read_csv("self_distribution/serial_requests.csv")
# serial_requests['order'] = range(len(serial_requests))
# sns.lineplot(data=serial_requests, x='order', y='response_time')
# plt.title('Request time to response Flask app')
# plt.show()

