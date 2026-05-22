import request from './request'

export function getProjectManagers(params) {
  return request.get('/project-managers', { params })
}

export function bindProjectManager(data) {
  return request.post('/project-managers', data)
}

export function unbindProjectManager(id) {
  return request.delete(`/project-managers/${id}`)
}
