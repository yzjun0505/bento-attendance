import request from './request'

export function getUsers(params) {
  return request.get('/users', { params })
}

export function getUserById(id) {
  return request.get(`/users/${id}`)
}

export function createUser(data) {
  return request.post('/users', data)
}

export function updateUser(id, data) {
  return request.put(`/users/${id}`, data)
}

export function deleteUser(id, data) {
  return request.delete(`/users/${id}`, { data })
}

export function resetPassword(id, data) {
  return request.put(`/users/${id}/reset-password`, data)
}

export function getCurrentUser() {
  return request.get('/users/me')
}

export function updateCurrentUser(data) {
  return request.put('/users/me', data)
}

export function changePassword(data) {
  return request.put('/users/me/password', data)
}
