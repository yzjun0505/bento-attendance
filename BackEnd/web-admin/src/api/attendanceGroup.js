import request from './request'

export function getAttendanceGroups(params) {
  return request.get('/attendance-groups', { params })
}

export function getAttendanceGroupById(id) {
  return request.get(`/attendance-groups/${id}`)
}

export function createAttendanceGroup(data) {
  return request.post('/attendance-groups', data)
}

export function updateAttendanceGroup(id, data) {
  return request.put(`/attendance-groups/${id}`, data)
}

export function deleteAttendanceGroup(id) {
  return request.delete(`/attendance-groups/${id}`)
}

export function addGroupMembers(id, userIds) {
  return request.post(`/attendance-groups/${id}/members`, { user_ids: userIds })
}

export function removeGroupMember(id, userId) {
  return request.delete(`/attendance-groups/${id}/members/${userId}`)
}
