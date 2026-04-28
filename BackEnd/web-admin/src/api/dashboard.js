import request from './request'

export function getDashboardStats() {
  return request.get('/dashboard/stats')
}

export function getDashboardTrend(params) {
  return request.get('/dashboard/trend', { params })
}

export function getDashboardDistribution() {
  return request.get('/dashboard/distribution')
}

export function getDashboardAnomalies(params) {
  return request.get('/dashboard/anomalies', { params })
}

export function getDashboardTodos(params) {
  return request.get('/dashboard/todos', { params })
}

