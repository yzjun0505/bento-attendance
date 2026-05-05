import request from './request'

export const getSchedules = (params) => request.get('/schedules', { params })
export const batchSchedule = (data) => request.post('/schedules/batch', data)
export const setRestDay = (id, isRest) => request.put(`/schedules/${id}/rest`, { is_rest: isRest })
export const deleteSchedule = (id) => request.delete(`/schedules/${id}`)
export const getCalendar = (date) => request.get('/schedules/calendar', { params: { date } })
