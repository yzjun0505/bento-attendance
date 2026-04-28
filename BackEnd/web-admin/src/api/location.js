import request from './request'

export function reportLocation(data) {
  return request.post('/location/report', data)
}

export function getLatestLocations(params) {
  return request.get('/location/latest', { params })
}

export function getOnlineCount() {
  return request.get('/location/online-count')
}

export function getLocationHistory(userId, params) {
  return request.get(`/location/history/${userId}`, { params })
}
