import request from './request'

export const getApprovals = (params) => request.get('/approvals/all', { params })
export const createApproval = (data) => request.post('/approvals', data)
export const approveApproval = (id, remark) => request.put(`/approvals/${id}/approve`, { remark })
export const rejectApproval = (id, remark) => request.put(`/approvals/${id}/reject`, { remark })
export const deleteApproval = (id) => request.delete(`/approvals/${id}`)
