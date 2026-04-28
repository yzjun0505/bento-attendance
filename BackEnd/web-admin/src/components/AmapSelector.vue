<template>
  <el-dialog title="在地图上选择位置" v-model="visible" width="800px" destroy-on-close @opened="initMap">
    <div class="map-dialog-content">
      <div class="search-bar">
        <el-input v-model="keyword" placeholder="搜索具体地点 (例: 阿里巴巴西溪园区)" clearable @keyup.enter="searchLocation">
          <template #append>
            <el-button :icon="Search" @click="searchLocation" />
          </template>
        </el-input>
      </div>
      <div style="position: relative; margin-top: 12px;">
        <div id="amap-container" style="width: 100%; height: 400px; border-radius: 8px; overflow: hidden;"></div>
        <!-- 搜索结果面板挂载点 -->
        <div id="search-panel" style="position: absolute; top: 10px; right: 10px; max-height: 380px; overflow-y: auto; background: white; border-radius: 4px; box-shadow: 0 2px 6px rgba(0,0,0,0.2); width: 280px; z-index: 10;"></div>
      </div>
      <div class="selection-info" v-if="selectedLocation">
        <strong>当前选中:</strong> {{ selectedLocation.address }} 
        <span style="color: #409EFF; margin-left: 12px;">(经度: {{ selectedLocation.lng }}, 纬度: {{ selectedLocation.lat }})</span>
      </div>
    </div>
    <template #footer>
      <div class="dialog-footer">
        <el-button @click="visible = false">取消</el-button>
        <el-button type="primary" @click="confirmSelection" :disabled="!selectedLocation">确认选择</el-button>
      </div>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, watch, nextTick } from 'vue'
import { Search } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'

const props = defineProps({
  modelValue: Boolean,
  initialLat: [Number, String],
  initialLng: [Number, String]
})

const emit = defineEmits(['update:modelValue', 'select'])

const visible = ref(false)
const keyword = ref('')
const selectedLocation = ref(null)

let mapInstance = null
let markerInstance = null
let placeSearch = null

watch(() => props.modelValue, (val) => {
  visible.value = val
})

watch(visible, (val) => {
  emit('update:modelValue', val)
  if (!val) {
    if (mapInstance) {
      mapInstance.destroy()
      mapInstance = null
    }
    keyword.value = ''
    selectedLocation.value = null
  }
})

function initMap() {
  if (!window.AMap) {
    ElMessage.error('高德地图API加载失败，请检查网络或Key配置')
    return
  }

  const defaultCenter = [116.397428, 39.90923] // Beijing default
  const center = (props.initialLng && props.initialLat) 
    ? [Number(props.initialLng), Number(props.initialLat)] 
    : defaultCenter

  mapInstance = new window.AMap.Map('amap-container', {
    zoom: 15,
    center: center
  })

  // Add initial marker if coordinates provided
  if (props.initialLng && props.initialLat) {
    markerInstance = new window.AMap.Marker({
      position: center,
      map: mapInstance
    })
    selectedLocation.value = {
      lng: props.initialLng,
      lat: props.initialLat,
      address: '现有位置'
    }
  }

  // Click on map to pick location
  mapInstance.on('click', (e) => {
    updateMarkerPosition(e.lnglat.getLng(), e.lnglat.getLat(), '已在地图上点击取点')
  })

  // Init PlaceSearch and Geolocation plugins
  window.AMap.plugin(['AMap.PlaceSearch', 'AMap.CitySearch'], () => {
    // 自动定位 (使用 CitySearch 根据 IP 定位，避免非 HTTPS 环境下 Geolocation 失效)
    if (!props.initialLng || !props.initialLat) {
      const citySearch = new window.AMap.CitySearch()
      citySearch.getLocalCity((status, result) => {
        if (status === 'complete' && result.info === 'OK') {
          // 定位到当前城市
          if (result && result.bounds) {
            mapInstance.setBounds(result.bounds)
          }
          console.log('自动定位城市成功', result.city)
        } else {
          console.warn('自动定位城市失败', result)
        }
      })
    }

    // 搜索插件
    placeSearch = new window.AMap.PlaceSearch({
      pageSize: 5,
      pageIndex: 1,
      map: mapInstance,
      panel: 'search-panel',
      city: '全国', // 默认全国范围搜索
      autoFitView: true
    })
    
    // When user selects a search result (from marker or list)
    const handleSelect = (e) => {
      const poi = e.data || e.poi
      if (poi && poi.location) {
        updateMarkerPosition(poi.location.lng, poi.location.lat, poi.name || poi.address)
      }
    }
    placeSearch.on('markerClick', handleSelect)
    placeSearch.on('listElementClick', handleSelect)
  })
}

function updateMarkerPosition(lng, lat, addressLabel) {
  if (markerInstance) {
    markerInstance.setPosition([lng, lat])
  } else {
    markerInstance = new window.AMap.Marker({
      position: [lng, lat],
      map: mapInstance
    })
  }
  
  selectedLocation.value = {
    lng: lng.toFixed(6),
    lat: lat.toFixed(6),
    address: addressLabel
  }
}

function searchLocation() {
  if (!keyword.value) return
  if (placeSearch) {
    placeSearch.search(keyword.value, (status, result) => {
      if (status !== 'complete' || result.info !== 'OK') {
        ElMessage.warning('未能搜到相关位置，请尝试其他关键词')
      }
    })
  }
}

function confirmSelection() {
  if (selectedLocation.value) {
    emit('select', { ...selectedLocation.value })
    visible.value = false
  }
}
</script>

<style scoped>
.map-dialog-content {
  padding: 10px 0;
}
.selection-info {
  margin-top: 12px;
  padding: 12px;
  background-color: var(--bg-card);
  border: 1px solid var(--border-light);
  border-radius: 8px;
  font-size: 14px;
}

:deep(.amap-sug-result) {
  z-index: 9999;
}
</style>
