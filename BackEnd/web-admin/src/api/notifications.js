import request from './request'

export function getNotifications(params) {
  return request.get('/notifications', { params })
}

export function getAllNotifications(params) {
  return request.get('/notifications/all', { params })
}

export function sendNotification(data) {
  return request.post('/notifications', data)
}

export function markAsRead(id) {
  return request.put(`/notifications/${id}/read`)
}

export function markAllRead() {
  return request.put('/notifications/read-all')
}

export function deleteNotification(id) {
  return request.delete(`/notifications/${id}`)
}
