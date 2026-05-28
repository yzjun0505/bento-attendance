import request from './request'

export function getProgressProjects() {
  return request.get('/projects/authorized')
}

export function getProjectSummary(projectId) {
  return request.get(`/projects/${projectId}/progress-summary`)
}

export function getProjectNodes(projectId, params) {
  return request.get(`/projects/${projectId}/nodes`, { params })
}

export function createProjectNode(projectId, data) {
  return request.post(`/projects/${projectId}/nodes`, data)
}

export function updateProjectNode(nodeId, data) {
  return request.put(`/nodes/${nodeId}`, data)
}

export function deleteProjectNode(nodeId) {
  return request.delete(`/nodes/${nodeId}`)
}

export function getNodeReports(nodeId, params) {
  return request.get(`/nodes/${nodeId}/reports`, { params })
}

export function reviewProjectNode(nodeId, data) {
  return request.post(`/nodes/${nodeId}/review`, data)
}
