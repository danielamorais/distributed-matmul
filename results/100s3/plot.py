import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

stats_history = pd.read_csv("self_distribution/dana_stats_history.csv")
stats_history_serial = pd.read_csv("self_distribution/serial_stats_history.csv")
stats_history_serial['order'] = range(len(stats_history_serial))
stats_history['order'] = range(len(stats_history))
sns.lineplot(data=stats_history, x='order', y='Requests/s', label="Dana")
sns.lineplot(data=stats_history_serial, x='order', y='Requests/s', label="Flask + Gunicorn")
plt.title('Requests/s Dana x Flask')
plt.legend()
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

