import axios from 'axios'
import { ElMessage } from 'element-plus'
import router from '@/router'

const request = axios.create({
  baseURL: '/api',
  timeout: 15000
})

let refreshingPromise = null

function clearAuthAndRedirect() {
  localStorage.removeItem('token')
  localStorage.removeItem('refresh_token')
  if (router.currentRoute.value.path !== '/login') {
    router.push('/login')
  }
}

async function refreshAccessToken() {
  if (refreshingPromise) return refreshingPromise

  const refreshToken = localStorage.getItem('refresh_token')
  if (!refreshToken) return null

  refreshingPromise = axios
    .post('/api/sessions/refresh', { refresh_token: refreshToken }, { timeout: 15000 })
    .then((response) => {
      const res = response.data
      if (res?.code !== 200 || !res?.data?.access_token) return null

      localStorage.setItem('token', res.data.access_token)
      if (res.data.refresh_token) {
        localStorage.setItem('refresh_token', res.data.refresh_token)
      }
      return res.data.access_token
    })
    .catch(() => null)
    .finally(() => {
      refreshingPromise = null
    })

  return refreshingPromise
}

async function retryWithFreshToken(config) {
  if (config?.skipAuthRefresh || config?.__retried) return null

  const token = await refreshAccessToken()
  if (!token) return null

  config.__retried = true
  config.headers = config.headers || {}
  config.headers.Authorization = `Bearer ${token}`
  return request(config)
}

// 请求拦截器
request.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => Promise.reject(error)
)

// 响应拦截器
request.interceptors.response.use(
  async (response) => {
    if (response.config.responseType === 'blob') {
      return response.data
    }
    const res = response.data
    if (res.code !== 200) {
      if (res.code === 401) {
        const retryResponse = await retryWithFreshToken(response.config)
        if (retryResponse) return retryResponse
        clearAuthAndRedirect()
      }
      if (!response.config.skipErrorMessage) {
        ElMessage.error(res.message || '请求失败')
      }
      return Promise.reject(new Error(res.message))
    }
    return res
  },
  async (error) => {
    if (error.response?.status === 401) {
      const retryResponse = await retryWithFreshToken(error.config)
      if (retryResponse) return retryResponse
      clearAuthAndRedirect()
    }

    const msg = error.response?.data?.message || error.message || '网络错误'
    if (!error.config?.skipErrorMessage) {
      ElMessage.error(msg)
    }
    return Promise.reject(error)
  }
)

export default request
