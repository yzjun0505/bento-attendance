import request from './request'

export function sendAiMessage(data) {
  return request.post('/ai/chat', data)
}

export function getAiConversations() {
  return request.get('/ai/conversations')
}

export function getAiMessages(id) {
  return request.get(`/ai/conversations/${id}`)
}

export function deleteAiConversation(id) {
  return request.delete(`/ai/conversations/${id}`)
}

export function confirmAiAction(id) {
  return request.post(`/ai/actions/${id}/confirm`)
}

export function getAiSuggestions(params = {}) {
  return request.get('/ai/suggestions', { params })
}

export function downloadAiReport(apiUrl) {
  const url = apiUrl.replace(/^\/api/, '')
  return request.get(url, { responseType: 'blob' })
}
