import React, { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';

interface PipeRig3DViewerProps {
  activeJoint?: number; // 1, 2, 3, 4
  onSelectJoint?: (jointId: number) => void;
  isLeaking?: boolean;
  leakIntensity?: number; // 0 to 1
  height?: number | string;
  showControls?: boolean;
}

export const PipeRig3DViewer: React.FC<PipeRig3DViewerProps> = ({
  activeJoint = 3,
  onSelectJoint,
  isLeaking = true,
  leakIntensity = 0.85,
  height = 420,
  showControls = true,
}) => {
  const mountRef = useRef<HTMLDivElement>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [autoRotate, setAutoRotate] = useState(false);

  // References to Three.js objects
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.PerspectiveCamera | null>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const pipeModelRef = useRef<THREE.Group | null>(null);
  const ringsRef = useRef<THREE.Mesh[]>([]);
  const dripsRef = useRef<{ mesh: THREE.Mesh; speed: number; startY: number }[]>([]);
  const animFrameRef = useRef<number | null>(null);

  // Pointer drag controls state
  const isDraggingRef = useRef(false);
  const prevPointerRef = useRef({ x: 0, y: 0 });
  const rotationRef = useRef({ x: 0.15, y: -0.45 });
  const zoomRef = useRef(4.5);

  useEffect(() => {
    const container = mountRef.current;
    if (!container) return;

    const width = container.clientWidth || 600;
    const heightPx = typeof height === 'number' ? height : container.clientHeight || 420;

    // 1. Scene setup
    const scene = new THREE.Scene();
    sceneRef.current = scene;
    scene.background = new THREE.Color(0x131416); // Carbon dark

    // 2. Camera setup
    const camera = new THREE.PerspectiveCamera(42, width / heightPx, 0.1, 100);
    camera.position.set(0, 0.8, zoomRef.current);
    camera.lookAt(0, 0, 0);
    cameraRef.current = camera;

    // 3. Renderer setup
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: 'high-performance' });
    renderer.setSize(width, heightPx);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.25;
    rendererRef.current = renderer;
    container.appendChild(renderer.domElement);

    // 4. Lighting setup (Cinematic warm industrial lighting)
    const ambientLight = new THREE.AmbientLight(0xffeedd, 0.7);
    scene.add(ambientLight);

    const keyLight = new THREE.DirectionalLight(0xffffff, 2.2);
    keyLight.position.set(5, 8, 6);
    scene.add(keyLight);

    const rimLight = new THREE.DirectionalLight(0xf07842, 2.8); // Burnt Orange rim
    rimLight.position.set(-6, -2, -5);
    scene.add(rimLight);

    const fillLight = new THREE.PointLight(0xffcba4, 1.5, 12);
    fillLight.position.set(0, 3, 2);
    scene.add(fillLight);

    // 5. Acoustic pulse rings group (surrounds defect joint)
    const ringGroup = new THREE.Group();
    scene.add(ringGroup);
    ringsRef.current = [];

    for (let i = 0; i < 3; i++) {
      const ringGeo = new THREE.TorusGeometry(0.35 + i * 0.15, 0.012, 16, 48);
      const ringMat = new THREE.MeshBasicMaterial({
        color: 0xf07842,
        transparent: true,
        opacity: 0.6 - i * 0.18,
      });
      const ringMesh = new THREE.Mesh(ringGeo, ringMat);
      ringMesh.rotation.y = Math.PI / 2;
      ringMesh.position.set(0.15, -0.05, 0); // At the main joint
      ringGroup.add(ringMesh);
      ringsRef.current.push(ringMesh);
    }

    // 6. Water drip droplets
    const dripGroup = new THREE.Group();
    scene.add(dripGroup);
    dripsRef.current = [];

    const dripGeo = new THREE.SphereGeometry(0.035, 12, 12);
    const dripMat = new THREE.MeshStandardMaterial({
      color: 0xa5d8ff,
      roughness: 0.1,
      metalness: 0.1,
      transparent: true,
      opacity: 0.85,
    });

    for (let i = 0; i < 2; i++) {
      const drip = new THREE.Mesh(dripGeo, dripMat);
      drip.position.set(0.15, -0.2 - i * 0.6, 0);
      dripGroup.add(drip);
      dripsRef.current.push({
        mesh: drip,
        speed: 0.02 + i * 0.01,
        startY: -0.15,
      });
    }

    // 7. Load user's real GLTF pipe model from /scene.gltf
    const loader = new GLTFLoader();
    setIsLoading(true);
    setLoadError(null);

    loader.load(
      '/scene.gltf',
      (gltf) => {
        const model = gltf.scene;
        pipeModelRef.current = model;

        // Auto-center and normalize size
        const box = new THREE.Box3().setFromObject(model);
        const center = box.getCenter(new THREE.Vector3());
        const size = box.getSize(new THREE.Vector3());

        model.position.sub(center); // Center geometry

        const maxDim = Math.max(size.x, size.y, size.z);
        if (maxDim > 0) {
          const targetScale = 3.2 / maxDim;
          model.scale.multiplyScalar(targetScale);
        }

        // Apply realistic metallic materials enhancement
        model.traverse((child) => {
          if ((child as THREE.Mesh).isMesh) {
            const mesh = child as THREE.Mesh;
            mesh.castShadow = true;
            mesh.receiveShadow = true;
            if (mesh.material) {
              const mat = mesh.material as THREE.MeshStandardMaterial;
              mat.roughness = Math.min(mat.roughness || 0.45, 0.6);
              mat.metalness = Math.max(mat.metalness || 0.5, 0.4);
              mat.envMapIntensity = 1.2;
            }
          }
        });

        scene.add(model);
        setIsLoading(false);
      },
      undefined,
      (err) => {
        console.error('Failed to load pipe GLTF model:', err);
        setLoadError('Failed to load 3D pipe model');
        setIsLoading(false);
      }
    );

    // 8. Animation loop
    const clock = new THREE.Clock();

    const animate = () => {
      const elapsedTime = clock.getElapsedTime();

      // Auto rotation or apply user rotation
      if (autoRotate && pipeModelRef.current) {
        rotationRef.current.y += 0.008;
      }

      if (pipeModelRef.current) {
        pipeModelRef.current.rotation.x = rotationRef.current.x;
        pipeModelRef.current.rotation.y = rotationRef.current.y;
      }

      // Animate ultrasonic acoustic pulse rings
      if (ringsRef.current.length > 0) {
        ringsRef.current.forEach((ring, idx) => {
          if (isLeaking) {
            ring.visible = true;
            const phase = (elapsedTime * 2.2 + idx * 0.7) % 2.0;
            const scale = 0.8 + phase * 0.9;
            ring.scale.set(scale, scale, scale);
            const mat = ring.material as THREE.MeshBasicMaterial;
            mat.opacity = Math.max(0, (1 - phase / 2.0) * leakIntensity * 0.8);
            ring.rotation.x = rotationRef.current.x;
            ring.rotation.y = rotationRef.current.y + Math.PI / 2;
          } else {
            ring.visible = false;
          }
        });
      }

      // Animate water dripping
      if (dripsRef.current.length > 0) {
        dripsRef.current.forEach((d) => {
          if (isLeaking) {
            d.mesh.visible = true;
            d.mesh.position.y -= d.speed;
            if (d.mesh.position.y < -1.4) {
              d.mesh.position.y = d.startY;
            }
          } else {
            d.mesh.visible = false;
          }
        });
      }

      renderer.render(scene, camera);
      animFrameRef.current = requestAnimationFrame(animate);
    };

    animFrameRef.current = requestAnimationFrame(animate);

    // 9. Resize handler
    const handleResize = () => {
      if (!container || !rendererRef.current || !cameraRef.current) return;
      const w = container.clientWidth || 600;
      const h = typeof height === 'number' ? height : container.clientHeight || 420;
      const cam = cameraRef.current;
      cam.aspect = w / h;
      cam.updateProjectionMatrix();
      rendererRef.current.setSize(w, h);
    };

    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      if (animFrameRef.current) cancelAnimationFrame(animFrameRef.current);
      if (rendererRef.current && rendererRef.current.domElement) {
        container.removeChild(rendererRef.current.domElement);
        rendererRef.current.dispose();
      }
    };
  }, [height, isLeaking, leakIntensity, autoRotate]);

  // Pointer drag handlers for smooth 3D orbit
  const handlePointerDown = (e: React.PointerEvent) => {
    isDraggingRef.current = true;
    prevPointerRef.current = { x: e.clientX, y: e.clientY };
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    if (!isDraggingRef.current) return;
    const deltaX = e.clientX - prevPointerRef.current.x;
    const deltaY = e.clientY - prevPointerRef.current.y;
    prevPointerRef.current = { x: e.clientX, y: e.clientY };

    rotationRef.current.y += deltaX * 0.008;
    rotationRef.current.x = Math.max(-1.2, Math.min(1.2, rotationRef.current.x + deltaY * 0.008));
  };

  const handlePointerUp = (e: React.PointerEvent) => {
    isDraggingRef.current = false;
    try {
      (e.target as HTMLElement).releasePointerCapture(e.pointerId);
    } catch {
      // ignore
    }
  };

  const handleWheel = (e: React.WheelEvent) => {
    e.preventDefault();
    if (!cameraRef.current) return;
    const cam = cameraRef.current;
    zoomRef.current = Math.max(2.2, Math.min(8.0, zoomRef.current + e.deltaY * 0.005));
    cam.position.z = zoomRef.current;
  };

  const resetView = () => {
    rotationRef.current = { x: 0.15, y: -0.45 };
    zoomRef.current = 4.5;
    if (cameraRef.current) {
      cameraRef.current.position.set(0, 0.8, 4.5);
    }
  };

  return (
    <div
      style={{
        position: 'relative',
        width: '100%',
        height: typeof height === 'number' ? `${height}px` : height,
        borderRadius: 10,
        overflow: 'hidden',
        border: '1px solid var(--color-warm-stone)',
        background: '#131416',
        touchAction: 'none',
      }}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onWheel={handleWheel}
    >
      {/* 3D WebGL Canvas Mount */}
      <div ref={mountRef} style={{ width: '100%', height: '100%', cursor: 'grab' }} />

      {/* Loading Overlay */}
      {isLoading && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            background: 'rgba(19, 20, 22, 0.85)',
            backdropFilter: 'blur(4px)',
            color: '#F7F5F0',
            zIndex: 10,
          }}
        >
          <div className="hg-spinner" style={{ width: 28, height: 28, marginBottom: 12 }} />
          <div style={{ fontSize: 13, fontWeight: 700, letterSpacing: '0.04em' }}>Loading 3D Pipeline Digital Twin…</div>
          <div style={{ fontSize: 11, color: '#716D67', marginTop: 4 }}>Rendering PBR Metallic Mesh (/scene.gltf)</div>
        </div>
      )}

      {/* Error Overlay */}
      {loadError && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            background: 'rgba(19, 20, 22, 0.9)',
            color: '#F07842',
            fontSize: 12,
            zIndex: 10,
          }}
        >
          ⚠️ {loadError}
        </div>
      )}

      {/* Top HUD Badges */}
      <div
        style={{
          position: 'absolute',
          top: 12,
          left: 12,
          display: 'flex',
          gap: 8,
          alignItems: 'center',
          pointerEvents: 'none',
          zIndex: 5,
        }}
      >
        <span
          style={{
            background: 'rgba(37,37,37,0.85)',
            border: '1px solid rgba(255,255,255,0.15)',
            borderRadius: 4,
            padding: '3px 8px',
            fontSize: 11,
            fontWeight: 700,
            color: '#F7F5F0',
            fontFamily: 'var(--font-mono)',
          }}
        >
          RIG-3D: INDUSTRIAL PIPE
        </span>
        {isLeaking ? (
          <span
            style={{
              background: 'rgba(240, 120, 66, 0.25)',
              border: '1px solid #F07842',
              borderRadius: 4,
              padding: '3px 8px',
              fontSize: 11,
              fontWeight: 700,
              color: '#F07842',
              display: 'inline-flex',
              alignItems: 'center',
              gap: 5,
            }}
          >
            <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#F07842' }} />
            LEAK ACTIVE @ JOINT #3
          </span>
        ) : (
          <span
            style={{
              background: 'rgba(34, 197, 94, 0.2)',
              border: '1px solid #22c55e',
              borderRadius: 4,
              padding: '3px 8px',
              fontSize: 11,
              fontWeight: 700,
              color: '#4ade80',
            }}
          >
            SEAL INTEGRITY: NORMAL
          </span>
        )}
      </div>

      {/* Quick Interactive Controls Toolbar */}
      {showControls && (
        <div
          style={{
            position: 'absolute',
            bottom: 12,
            left: 12,
            right: 12,
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            zIndex: 5,
            pointerEvents: 'auto',
          }}
        >
          {/* Joint Selectors */}
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {[
              { id: 1, label: 'J1: Flange' },
              { id: 2, label: 'J2: Elbow' },
              { id: 3, label: 'J3: Leak Joint' },
              { id: 4, label: 'J4: Valve' },
            ].map((j) => (
              <button
                key={j.id}
                onClick={(e) => {
                  e.stopPropagation();
                  onSelectJoint?.(j.id);
                }}
                style={{
                  fontSize: 10,
                  fontFamily: 'var(--font-mono)',
                  fontWeight: 700,
                  padding: '4px 8px',
                  borderRadius: 4,
                  border: activeJoint === j.id ? '1px solid #F07842' : '1px solid rgba(255,255,255,0.2)',
                  background: activeJoint === j.id ? 'rgba(240, 120, 66, 0.35)' : 'rgba(25,25,25,0.7)',
                  color: activeJoint === j.id ? '#F07842' : '#E9E5DE',
                  cursor: 'pointer',
                  transition: '0.15s',
                }}
              >
                {j.label}
              </button>
            ))}
          </div>

          {/* Action buttons */}
          <div style={{ display: 'flex', gap: 6 }}>
            <button
              onClick={(e) => {
                e.stopPropagation();
                setAutoRotate(!autoRotate);
              }}
              style={{
                fontSize: 10,
                fontWeight: 600,
                padding: '4px 8px',
                borderRadius: 4,
                border: '1px solid rgba(255,255,255,0.2)',
                background: autoRotate ? '#F07842' : 'rgba(25,25,25,0.7)',
                color: autoRotate ? '#17100B' : '#E9E5DE',
                cursor: 'pointer',
              }}
              title="Toggle automatic rotation"
            >
              🔄 {autoRotate ? 'Rotating' : 'Rotate'}
            </button>
            <button
              onClick={(e) => {
                e.stopPropagation();
                resetView();
              }}
              style={{
                fontSize: 10,
                fontWeight: 600,
                padding: '4px 8px',
                borderRadius: 4,
                border: '1px solid rgba(255,255,255,0.2)',
                background: 'rgba(25,25,25,0.7)',
                color: '#E9E5DE',
                cursor: 'pointer',
              }}
              title="Reset camera view"
            >
              🎯 Reset
            </button>
          </div>
        </div>
      )}

      {/* Interaction Hint */}
      <div
        style={{
          position: 'absolute',
          top: 12,
          right: 12,
          fontSize: 10,
          color: '#716D67',
          background: 'rgba(25,25,25,0.6)',
          padding: '3px 7px',
          borderRadius: 4,
          pointerEvents: 'none',
        }}
      >
        🖱️ Drag to orbit · Scroll to zoom
      </div>
    </div>
  );
};

export default PipeRig3DViewer;
