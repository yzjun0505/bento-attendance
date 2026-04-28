import request from './request'

export function submitCheckin(data) {
  return request.post('/checkin', data)
}

export function getCheckins(params) {
  return request.get('/checkin', { params })
}

export function getTodayStats() {
  return request.get('/checkin/today-stats')
}

export function exportCheckins(params) {
  return request.get('/checkin/export', { params, responseType: 'blob' })
}

export function searchByCode(code) {
  return request.get('/checkin/search-code', { params: { code } })
}
