from setuptools import find_packages, setup
import os
from glob import glob

package_name = 'plan'

setup(
    name=package_name,
    version='2.2.0',  # Updated: v2.2 with A* detour planning & simple anti-stuck
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        # Install rviz config files
        (os.path.join('share', package_name, 'rviz'), glob('rviz/*.rviz')),
    ],
    install_requires=[
        'setuptools',
        'numpy',
        'scipy',
    ],
    zip_safe=True,
    maintainer='ghostzero',
    maintainer_email='yinpuchen0@gmail.com',
    author='ghostzero',
    author_email='yinpuchen0@gmail.com',
    description='Planning and perception package for VRX autonomous navigation with A* detour planning, OKO perception v2.1, and SPUTNIK planner v2.2.',
    license='Apache-2.0',
    keywords=['ROS2', 'VRX', 'autonomous navigation', 'path planning', 'obstacle detection', 'LiDAR', 'A*'],
    tests_require=['pytest'],
    python_requires='>=3.10',
    classifiers=[
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
        'Programming Language :: Python :: 3.12',
        'License :: OSI Approved :: Apache Software License',
        'Operating System :: OS Independent',
        'Topic :: Scientific/Engineering :: Robotics',
    ],
    entry_points={
        'console_scripts': [
            # === Core Vostok1 nodes (launched by vostok1.launch.yaml) ===
            'sputnik_planner = plan.sputnik_planner:main',
            'oko_perception = plan.oko_perception:main',
            'waypoint_visualizer = plan.waypoint_visualizer:main',
            'vostok1_cli = plan.vostok1_cli:main',
            'health_check_service = plan.health_check_service:main',

            # === Standalone utilities (not in launch file, run manually) ===
            'mission_trigger = plan.mission_trigger:main',         # Manual mission start trigger
            'tf_broadcaster = plan.tf_broadcaster:main',           # TF frame publisher
            'tf_broadcaster_gazebo = plan.tf_broadcaster_gazebo:main',  # TF for Gazebo sim
            'tf_broadcaster_gps = plan.tf_broadcaster_gps:main',   # TF from GPS data
            'simple_perception = plan.simple_perception:main',     # Simplified obstacle detection
            'gps_imu_pose = plan.gps_imu_pose:main',              # GPS+IMU pose estimation
            'pose_filter = plan.pose_filter:main',                 # Pose smoothing filter

            # === Testing / debug variants ===
            'oko_perception_fixed = plan.oko_perception_fixed:main',  # OKO with debug fixes
        ],
    },
)