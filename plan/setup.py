from glob import glob
import os

from setuptools import find_packages, setup

package_name = 'plan'

setup(
    name=package_name,
    # v2.2: A* detour planning and simple anti-stuck.
    version='2.2.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        # Install rviz config files
        (os.path.join('share', package_name, 'rviz'), glob('rviz/*.rviz')),
        # Install health-check script for the in-process service.
        (
            os.path.join('share', package_name, 'scripts'),
            glob('../one_click_launch_all/health_check_*.sh'),
        ),
    ],
    install_requires=[
        'setuptools',
        'numpy',
    ],
    zip_safe=True,
    maintainer='Ghostzero00018',
    maintainer_email='yinpuchen0@gmail.com',
    author='Ghostzero00018',
    author_email='yinpuchen0@gmail.com',
    description=(
        'Planning and perception package for VRX autonomous navigation with '
        'A* detour planning, LiDAR perception v2.1, and waypoint planner v2.2.'
    ),
    license='Apache-2.0',
    keywords=[
        'ROS2',
        'VRX',
        'autonomous navigation',
        'path planning',
        'obstacle detection',
        'LiDAR',
        'A*',
    ],
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
            # === Core AutoBoat nodes (launched by autoboat.launch.yaml) ===
            'waypoint_planner = plan.waypoint_planner:main',
            'lidar_perception = plan.lidar_perception:main',
            'waypoint_visualizer = plan.waypoint_visualizer:main',
            'person_stop_monitor = plan.person_stop_monitor:main',
            'autoboat_cli = plan.autoboat_cli:main',
            'health_check_service = plan.health_check_service:main',
        ],
    },
)
