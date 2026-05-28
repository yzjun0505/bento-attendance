import request from './request'

export function getProjectClients(params) {
  return request.get('/project-clients', { params })
}

export function bindProjectClient(data) {
  return request.post('/project-clients', data)
}

export function unbindProjectClient(id) {
  return request.delete(`/project-clients/${id}`)
}
