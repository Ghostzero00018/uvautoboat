from setuptools import find_packages, setup

package_name = 'control'

setup(
    name=package_name,
    # v2.1: simple anti-stuck, drift compensation, and waypoint approach tuning.
    version='2.1.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
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
        'Control package for VRX WAM-V with heading controller v2.1 featuring '
        'simple anti-stuck system, Kalman drift compensation, and adaptive '
        'waypoint approach.'
    ),
    license='Apache-2.0',
    keywords=[
        'ROS2',
        'VRX',
        'thruster control',
        'PID',
        'obstacle avoidance',
        'anti-stuck',
        'drift compensation',
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
            # === Core AutoBoat node (launched by autoboat.launch.yaml) ===
            'heading_controller = control.heading_controller:main',

            # === Standalone utilities (not in launch file, run manually) ===
            # Manual thruster control for testing.
            'keyboard_teleop = control.keyboard_teleop:main',
        ],
    },
)
