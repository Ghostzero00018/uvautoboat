#include "rclcpp/rclcpp.hpp"
#include "sensor_msgs/msg/nav_sat_fix.hpp"
#include "sensor_msgs/msg/imu.hpp"
#include "geometry_msgs/msg/twist.hpp"
#include "mavlink/v2.0/common/mavlink.h"

#include "tf2_geometry_msgs/tf2_geometry_msgs.h"
#include "tf2/LinearMath/Quaternion.h"
#include "tf2/LinearMath/Matrix3x3.h"

#include <boost/asio.hpp>
#include <thread>
#include <cmath>

using boost::asio::ip::udp;

class BridgeNode : public rclcpp::Node {
public:
  BridgeNode()
  : Node("usv_mav_bridge"),
    io_context_(),
    socket_out_(new udp::socket(io_context_)),
    socket_in_(new udp::socket(io_context_))
  {
    system_id_ = this->declare_parameter<int>("system_id", 1);
    component_id_ = this->declare_parameter<int>("component_id", 200);
    udp_send_port_ = this->declare_parameter<int>("udp_send_port", 14551);
    udp_recv_port_ = this->declare_parameter<int>("udp_recv_port", 14555);

    // Set up endpoints and sockets
    endpoint_ap_ = udp::endpoint(boost::asio::ip::address::from_string("127.0.0.1"), udp_send_port_);
    socket_out_->open(udp::v4());

    udp::endpoint listen_endpoint(udp::v4(), udp_recv_port_);
    socket_in_->open(udp::v4());
    socket_in_->bind(listen_endpoint);

    // Subscriptions
    gps_sub_ = this->create_subscription<sensor_msgs::msg::NavSatFix>(
      "/gps/fix", 10, std::bind(&BridgeNode::gps_callback, this, std::placeholders::_1));

    imu_sub_ = this->create_subscription<sensor_msgs::msg::Imu>(
      "/imu/data", 10, std::bind(&BridgeNode::imu_callback, this, std::placeholders::_1));

    cmd_vel_pub_ = this->create_publisher<geometry_msgs::msg::Twist>("/cmd_vel", 10);

    // Start receiving thread
    recv_thread_ = std::thread(std::bind(&BridgeNode::recv_loop, this));

    // Heartbeat
    heartbeat_timer_ = this->create_wall_timer(
      std::chrono::seconds(1),
      std::bind(&BridgeNode::send_heartbeat, this));
  }

  ~BridgeNode() {
    socket_in_->close();
    socket_out_->close();
    io_context_.stop();
    if (recv_thread_.joinable()) {
      recv_thread_.join();
    }
  }

private:
  // Parameters
  int system_id_, component_id_;
  int udp_send_port_, udp_recv_port_;

  // MAVLink socket
  boost::asio::io_context io_context_;
  std::unique_ptr<udp::socket> socket_out_, socket_in_;
  udp::endpoint endpoint_ap_;

  // ROS Interfaces
  rclcpp::Subscription<sensor_msgs::msg::NavSatFix>::SharedPtr gps_sub_;
  rclcpp::Subscription<sensor_msgs::msg::Imu>::SharedPtr imu_sub_;
  rclcpp::Publisher<geometry_msgs::msg::Twist>::SharedPtr cmd_vel_pub_;
  rclcpp::TimerBase::SharedPtr heartbeat_timer_;

  std::thread recv_thread_;

  // === Callbacks ===

  void gps_callback(const sensor_msgs::msg::NavSatFix::SharedPtr msg) {
    if (msg->status.status < sensor_msgs::msg::NavSatStatus::STATUS_FIX) return;

    mavlink_message_t mav_msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    mavlink_msg_global_position_int_pack(
      system_id_, component_id_, &mav_msg,
      this->get_clock()->now().nanoseconds() / 1000,
      msg->latitude * 1e7,
      msg->longitude * 1e7,
      msg->altitude * 1000, // mm
      msg->altitude * 1000,
      0, 0, 0, 0);

    size_t len = mavlink_msg_to_send_buffer(buf, &mav_msg);
    socket_out_->send_to(boost::asio::buffer(buf, len), endpoint_ap_);
  }

  void imu_callback(const sensor_msgs::msg::Imu::SharedPtr msg) {
    tf2::Quaternion q(
      msg->orientation.x,
      msg->orientation.y,
      msg->orientation.z,
      msg->orientation.w);

    double roll, pitch, yaw;
    tf2::Matrix3x3(q).getRPY(roll, pitch, yaw);

    mavlink_message_t mav_msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    mavlink_msg_attitude_pack(
      system_id_, component_id_, &mav_msg,
      this->get_clock()->now().nanoseconds() / 1000,
      roll, pitch, yaw,
      msg->angular_velocity.x,
      msg->angular_velocity.y,
      msg->angular_velocity.z);

    size_t len = mavlink_msg_to_send_buffer(buf, &mav_msg);
    socket_out_->send_to(boost::asio::buffer(buf, len), endpoint_ap_);
  }

  void send_heartbeat() {
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    mavlink_msg_heartbeat_pack(
      system_id_, component_id_, &msg,
      MAV_TYPE_SURFACE_BOAT,
      MAV_AUTOPILOT_GENERIC,
      MAV_MODE_GUIDED_ARMED,
      0,
      MAV_STATE_ACTIVE);

    size_t len = mavlink_msg_to_send_buffer(buf, &msg);
    socket_out_->send_to(boost::asio::buffer(buf, len), endpoint_ap_);
  }

  // === Receive Loop ===

  void recv_loop() {
    uint8_t recv_buf[2048];
    udp::endpoint sender_endpoint;

    while (rclcpp::ok()) {
      size_t len = socket_in_->receive_from(boost::asio::buffer(recv_buf), sender_endpoint);
      mavlink_message_t msg;
      mavlink_status_t status;

      for (size_t i = 0; i < len; ++i) {
        if (mavlink_parse_char(MAVLINK_COMM_0, recv_buf[i], &msg, &status)) {
          switch (msg.msgid) {
            case MAVLINK_MSG_ID_COMMAND_LONG: {
              mavlink_command_long_t cmd;
              mavlink_msg_command_long_decode(&msg, &cmd);
              RCLCPP_INFO(this->get_logger(), "Received COMMAND_LONG: %d", cmd.command);
              break;
            }
            case MAVLINK_MSG_ID_SERVO_OUTPUT_RAW: {
              mavlink_servo_output_raw_t servo;
              mavlink_msg_servo_output_raw_decode(&msg, &servo);
              geometry_msgs::msg::Twist cmd_vel;
              // Example for 2 motors: channels 1 and 2
              cmd_vel.linear.x = (servo.servo1_raw + servo.servo2_raw) / 2.0 / 1000.0;
              cmd_vel.angular.z = (servo.servo2_raw - servo.servo1_raw) / 1000.0;
              cmd_vel_pub_->publish(cmd_vel);
              break;
            }
          }
        }
      }
    }
  }
};